const ByteWriter = @import("byte_writer").ByteWriter;
const ir = @import("ir");
const std = @import("std");

test "" {
    std.testing.refAllDecls(@This());
}

pub const x86_64 = @import("x86_64.zig");
pub const aarch64 = @import("aarch64.zig");

const log = std.log.scoped(.codegen);

pub const ExtRef = struct {};

pub const RelocationType = enum {
    rel_instr_addr,
    abs,
};

pub fn CodeGenerator(comptime platform: type) type {
    const UnresolvedInstrRef = struct {
        fixup: platform.Relocation,
        id: usize,
    };

    const ResolvedInstrRef = struct {
        offset: usize,
    };

    const Ident = struct {
        name: []const u8,
        stack_offset: platform.offset_type,
    };

    return struct {
        unresolved_refs: std.ArrayList(UnresolvedInstrRef),
        resolved_refs: std.ArrayList(ResolvedInstrRef),
        relocations: std.ArrayList(platform.Relocation),

        stack_offsets: std.ArrayList(platform.offset_type) = undefined,

        curr_stack_bytes: platform.offset_type = 0,
        max_stack_bytes: platform.offset_type = 0,

        pub fn init(alloc: *std.mem.Allocator) @This() {
            return .{
                .unresolved_refs = std.ArrayList(UnresolvedInstrRef).init(alloc),
                .resolved_refs = std.ArrayList(ResolvedInstrRef).init(alloc),
                .relocations = std.ArrayList(platform.Relocation).init(alloc),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.unresolved_refs.deinit();
            self.resolved_refs.deinit();
            self.relocations.deinit();
        }

        fn getRef(self: *@This(), idx: usize) ?ResolvedInstrRef {
            if (self.resolved_refs.items.len < idx)
                return null;

            return self.resolved_refs.items[idx];
        }

        fn stackOffset(self: *@This(), ref: ir.StackVarRef) platform.offset_type {
            return self.stack_offsets.items[1 + ref.idx] + @intCast(platform.offset_type, ref.offset);
        }

        fn addStackSlot(self: *@This(), size: usize) !platform.offset_type {
            const offset = self.curr_stack_bytes;
            try self.stack_offsets.append(offset);
            self.curr_stack_bytes = offset + @intCast(platform.offset_type, size);

            if (self.max_stack_bytes < self.curr_stack_bytes)
                self.max_stack_bytes = self.curr_stack_bytes;

            return @intCast(platform.offset_type, self.stack_offsets.items.len - 1);
        }

        pub fn singleInstr(self: *@This(), instr: ir.Instruction, output: *ByteWriter) !void {
            switch (instr) {
                .ref_next_instruction => |ref| {
                    if (ref.id != self.resolved_refs.items.len) {
                        @panic("Ref ids not in order!");
                    }

                    var i: usize = 0;
                    while (i < self.unresolved_refs.items.len) {
                        const item = &self.unresolved_refs.items[i];
                        if (item.id == ref.id) {
                            if (item.fixup.isRelative()) {
                                item.fixup.applyRelative(output, @intCast(i64, output.currentOffset()));
                            } else {
                                // @TODO: We have to emit a relocation for this one
                                unreachable;
                            }
                            _ = self.unresolved_refs.swapRemove(i);
                        }
                    }
                    try self.resolved_refs.append(.{
                        .offset = output.currentOffset(),
                    });
                },

                .add_stack => |push| _ = try self.addStackSlot(push.size),
                .drop_stack => |_| {
                    self.curr_stack_bytes = self.stack_offsets.items[self.stack_offsets.items.len - 2];
                    _ = self.stack_offsets.pop();
                },

                .load_constant => |value| try platform.loadConstant(output, value),
                .add_constant => |value| try platform.addConstant(output, value),
                .compare_constant => |value| try platform.compareConstant(output, value),

                // Adress/load/store stack
                .adress_stack_var => |adr| try platform.adrStack(output, self.stackOffset(adr)),
                .load_stack_var => |load| try platform.loadStack(output, load.sign_extend, load.stack_op.bit_size, self.stackOffset(load.stack_op.stack_var)),
                .store_stack_var => |store| try platform.storeStack(output, store.bit_size, self.stackOffset(store.stack_var)),

                // Compare with a value on the stack
                .compare_stack_var => |cmp| try platform.compareStack(output, cmp.bit_size, self.stackOffset(cmp.stack_var)),

                .bitxor_stack_var => |bxor| try platform.bitXorStack(output, bxor.bit_size, self.stackOffset(bxor.stack_var)),
                .bitor_stack_var => |bor| try platform.bitXorStack(output, bor.bit_size, self.stackOffset(bor.stack_var)),
                .bitand_stack_var => |band| try platform.bitXorStack(output, band.bit_size, self.stackOffset(band.stack_var)),

                .jump => |jmp| {
                    if (self.getRef(jmp.id)) |resolved| {
                        try platform.jumpRef(output, jmp.condition, resolved.offset);
                    } else {
                        try self.unresolved_refs.append(.{
                            .id = jmp.id,
                            .fixup = try platform.jumpReloc(output, jmp.condition),
                        });
                    }
                },

                // Adress/load/store an external value
                .adress_xref => |ext| try self.relocations.append(try platform.emitAdrReloc(output, ext)),
                .load_xref => |load| try self.relocations.append(try platform.emitLoadReloc(output, load.sign_extend, load.bit_size, load.extref)),
                .store_xref => |store| try self.relocations.append(try platform.emitStoreReloc(output, store.bit_size, store.extref)),

                .ptr_store_constant => |store| try platform.ptrStoreConstant(output, store.bit_size, store.value, @intCast(platform.offset_type, store.store_offset)),
                .ptr_store => |store| try platform.ptrStore(output, store.bit_size, self.stackOffset(store.ptr_loc), @intCast(platform.offset_type, store.store_offset)),
                .ptr_load => |load| try platform.ptrLoad(output, load.sign_extend, load.bit_size, self.stackOffset(load.ptr_loc), @intCast(platform.offset_type, load.load_offset)),
            }
        }

        pub fn generateCode(self: *@This(), instrs: []const ir.Instruction, output: *ByteWriter) !void {
            for (instrs) |instr| {
                try self.singleInstr(instr, output);
            }
        }

        pub fn generateFunction(self: *@This(), instrs: []const ir.Instruction, output: *ByteWriter) !void {
            const stack_space_ref: ByteWriter.Ref = try platform.prepareFunction(output);

            var offset_alloc = std.heap.stackFallback(4096, std.heap.page_allocator);
            self.stack_offsets = std.ArrayList(platform.offset_type).init(&offset_alloc.allocator);
            try self.stack_offsets.append(0);

            try self.generateCode(instrs, output);

            if (self.unresolved_refs.items.len > 0) {
                log.err("{} unresolved references!", .{self.unresolved_refs.items.len});
            }

            try platform.endFunction(output, stack_space_ref, self.max_stack_bytes);
        }
    };
}

const test_platforms = [_]type{
    x86_64,
    aarch64,
};

fn testInstrs(instrs: []const ir.Instruction) !void {
    log.warn("Compiling function: {any}\n\n-------\n", .{instrs});

    inline for (test_platforms) |platform| {
        var genny = CodeGenerator(platform).init(std.testing.allocator);
        defer genny.deinit();

        var writer = ByteWriter.init(std.testing.allocator);
        defer writer.deinit();

        try genny.generateFunction(instrs, &writer);

        log.warn("{s} generated bytes: {}", .{ platform.name, std.fmt.fmtSliceHexLower(writer.storage.items) });
    }

    log.warn("\n\n-------\n", .{});
}

test "Load 0x1337" {
    try testInstrs(&[_]ir.Instruction{
        .{ .load_constant = 0x1337 },
    });
}

test "Store accum to null" {
    try testInstrs(&[_]ir.Instruction{
        .{ .load_constant = 0 },
        .{ .add_stack = .{
            .size = 8,
        } },
        .{ .store_stack_var = .{
            .bit_size = 64,
            .stack_var = .{
                .idx = 0,
                .offset = 0,
            },
        } },
        .{ .load_constant = 0x1337 },
        .{ .ptr_store = .{
            .bit_size = 64,
            .store_offset = 0,
            .ptr_loc = .{
                .idx = 0,
                .offset = 0,
            },
        } },
    });
}

test "Store constant to null" {
    try testInstrs(&[_]ir.Instruction{
        .{ .load_constant = 0 },
        .{ .ptr_store_constant = .{
            .store_offset = 0,
            .bit_size = 64,
            .value = 0x1337,
        } },
    });
}
