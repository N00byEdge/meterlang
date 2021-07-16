const ByteWriter = @import("byte_writer").ByteWriter;
const std = @import("std");
const ir = @import("ir");

test "" {
    std.testing.refAllDecls(@This());
}

pub const ptr_type = u64;
pub const offset_type = i32;

pub const name = "x86_64";

const RelocationType = enum {
    rel32jmp,
};

pub const Relocation = struct {
    reltype: RelocationType,
    bytes: ByteWriter.Ref,

    pub fn isRelative(self: *const @This()) bool {
        return switch (self.reltype) {
            .rel32jmp => true,
        };
    }

    pub fn applyAbsolute(self: *const @This(), output: *ByteWriter, target_offset: usize, base_addr: ptr_type) void {
        return switch (self.reltype) {
            .rel32jmp => unreachable,
        };
    }

    pub fn applyRelative(self: *const @This(), output: *ByteWriter, target_offset: i65) void {
        const rel_addr = target_offset - self.bytes.offset;

        return switch (self.reltype) {
            .rel32jmp => std.mem.writeIntLittle(i32, output.bytes(self.bytes)[0..4], @intCast(i32, rel_addr - 4)),
        };
    }
};

pub fn prepareFunction(output: *ByteWriter) !ByteWriter.Ref {
    return output.writeBytes(&[_]u8{
        0x55, // push rbp
        0x48, 0x89, 0xE5, // mov rbp, rsp
        0x48, 0x81, 0xEC, undefined, undefined, undefined, undefined, // sub rsp, imm32
    });
}

pub fn endFunction(output: *ByteWriter, stack_space_ref: ByteWriter.Ref, local_variable_bytes: offset_type) !void {
    std.mem.writeIntLittle(offset_type, output.bytes(stack_space_ref)[7..][0..4], local_variable_bytes);
    _ = try output.writeBytes(&[_]u8{
        0x48, 0x89, 0xEC, // mov rsp, rbp
        0x5D, // pop rbp
        0xC3, // ret
    });
}

const RegisterValue = struct {
    value: u64,
    bits: u7,
};

/// Gets you the 64 bit register representation of a value and the number
/// of bits minimum (in steps of 8, 16, 32, 64) to interpret it with the correct sign value
fn registerValueSigned(value: i65) RegisterValue {
    var real_bit_size: u7 = 64;

    const eql: i1 = if (value < 0) -1 else 0;

    if (@truncate(i32, value >> 31) == eql) {
        real_bit_size = 32;

        if (@truncate(i16, value >> 15) == eql) {
            real_bit_size = 16;

            if (@truncate(i8, value >> 7) == eql) {
                real_bit_size = 8;
            }
        }
    }

    return .{
        .bits = real_bit_size,
        .value = @bitCast(u64, @truncate(i64, value)),
    };
}

test "registerValueSigned" {
    try std.testing.expectEqual(registerValueSigned(0x44), RegisterValue{
        .bits = 8,
        .value = 0x44,
    });

    try std.testing.expectEqual(registerValueSigned(0x84), RegisterValue{
        .bits = 16,
        .value = 0x84,
    });

    try std.testing.expectEqual(registerValueSigned(-1), RegisterValue{
        .bits = 8,
        .value = 0xFFFFFFFFFFFFFFFF,
    });

    try std.testing.expectEqual(registerValueSigned(-0x80), RegisterValue{
        .bits = 8,
        .value = 0xFFFFFFFFFFFFFF80,
    });

    try std.testing.expectEqual(registerValueSigned(-0x81), RegisterValue{
        .bits = 16,
        .value = 0xFFFFFFFFFFFFFF7F,
    });
}

fn registerValueUnsigned(value: i65) RegisterValue {
    // Is this ever needed in x86??
    unreachable;
}

pub fn loadConstant(output: *ByteWriter, value: i65) !void {
    const reg = registerValueSigned(value);

    switch (reg.bits) {
        8 => {
            var buf = [_]u8{ 0x6A, @truncate(u8, reg.value), 0x58 }; // push imm8; pop rax;
            _ = try output.writeBytes(buf[0..]);
        },
        16, 32 => {
            var buf = [_]u8{0x68} ++ [_]u8{undefined} ** 4 ++ [_]u8{0x58}; // push imm32; pop rax;
            std.mem.writeIntLittle(u32, buf[1..5], @truncate(u32, reg.value));
            _ = try output.writeBytes(buf[0..]);
        },
        64 => {
            var buf = [_]u8{ 0x48, 0xB8 } ++ [_]u8{undefined} ** 8; // movabs rax, imm64
            std.mem.writeIntLittle(u64, buf[2..10], reg.value);
            _ = try output.writeBytes(buf[0..]);
        },
        else => unreachable,
    }
}

pub fn addConstant(output: *ByteWriter, value: i65) !void {
    switch (value) {
        -1 => {
            _ = try output.writeBytes(&[_]u8{
                0x48, 0xFF, 0xC8, // dec rax
            });
            return;
        },
        1 => {
            _ = try output.writeBytes(&[_]u8{
                0x48, 0xFF, 0xC0, // inc rax
            });
            return;
        },
        else => {},
    }

    const reg = registerValueSigned(value);

    switch (reg.bits) {
        8 => {
            var buf = [_]u8{ 0x48, 0x83, 0xC0, @truncate(u8, reg.value) }; // add rax, imm8
            _ = try output.writeBytes(buf[0..]);
        },
        16, 32 => {
            var buf = [_]u8{ 0x48, 0x05 } ++ [_]u8{undefined} ** 4; // add rax, imm32
            std.mem.writeIntLittle(u32, buf[2..6], @truncate(u32, reg.value));
            _ = try output.writeBytes(buf[0..]);
        },
        else => unreachable,
    }
}

pub fn compareConstant(output: *ByteWriter, value: i65) !void {
    const reg = registerValueSigned(value);

    switch (reg.bits) {
        8 => {
            var buf = [_]u8{ 0x48, 0x83, 0xf8, @truncate(u8, reg.value) }; // cmp rax, imm8
            _ = try output.writeBytes(buf[0..]);
        },
        16, 32 => {
            var buf = [_]u8{ 0x48, 0x3D } ++ [_]u8{undefined} ** 4; // cmp rax, imm32
            std.mem.writeIntLittle(u32, buf[2..6], @truncate(u32, reg.value));
            _ = try output.writeBytes(buf[0..]);
        },
        else => unreachable,
    }
}

pub fn adrStack(output: *ByteWriter, offset: offset_type) !void {
    const reg = registerValueSigned(-offset - 8);

    switch (reg.bits) {
        8 => {
            var buf = [_]u8{ 0x48, 0x8D, 0x45, @truncate(u8, reg.value) }; // lea rax, [rbp + imm8]
            _ = try output.writeBytes(buf[0..]);
        },
        16, 32 => {
            var buf = [_]u8{ 0x48, 0x8D, 0x85 } ++ [_]u8{0xAA} ** 4; // lea rax, [rbp + imm32]
            std.mem.writeIntLittle(u32, buf[3..7], @truncate(u32, reg.value));
            _ = try output.writeBytes(buf[0..]);
        },
        else => unreachable,
    }
}

const StackRegMode = enum {
    SignExtendLoad,
    ZeroExtendLoad,
    Store,
};

fn writeStackLoad(output: *ByteWriter, sign_extend: bool, bit_size: u7, reg_byte: u8, regnum: u8) !void {
    // zig fmt: off
    switch(bit_size) {
        8 => _ = try output.writeBytes(&[_]u8{ // mov{z,s}x r64, byte [rbp + imm]
            0x48, 0x0F,
            if(sign_extend) 0xBE else 0xB6,
            reg_byte,
        }),
        16 => _ = try output.writeBytes(&[_]u8{ // mov{z,s}x r64, word [rbp + imm]
            0x48, 0x0F,
            if(sign_extend) 0xBF else 0xB7,
            reg_byte,
        }),
        32 => {
            if(sign_extend) {
                _ = try output.writeBytes(&[_]u8{0x48, 0x63, reg_byte}); // movsx r64, dword [rbp + imm]
            } else {
                _ = try output.writeBytes(&[_]u8{0x8B, reg_byte}); // mov r32, [rbp + imm]
            }
        },
        64 => _ = try output.writeBytes(&[_]u8{0x48, 0x8B, reg_byte}), // mov r64, [rbp + imm]
        else => unreachable,
    }
    // zig fmt: on
}

fn writeStackStore(output: *ByteWriter, bit_size: u7, reg_byte: u8, regnum: u8) !void {
    switch (bit_size) {
        8 => {
            // mov byte [rbp + imm], r8
            switch (regnum) {
                0...3 => {},
                4...8 => _ = try output.writeLittle(u8, 0x40),
                else => unreachable,
            }
            _ = try output.writeBytes(&[_]u8{ 0x88, reg_byte });
        },
        16 => _ = try output.writeBytes(&[_]u8{ 0x66, 0x89, reg_byte }), // mov word [rbp + imm], r16
        32 => _ = try output.writeBytes(&[_]u8{ 0x89, reg_byte }), // mov dword [rbp + imm], r32
        64 => _ = try output.writeBytes(&[_]u8{ 0x48, 0x89, reg_byte }), // mov qword [rbp + imm], r64
        else => unreachable,
    }
}

fn stackRegOp(output: *ByteWriter, mode: StackRegMode, bit_size: u7, stack_offset: i65, regnum: u8) !void {
    const ptr_offset_reg = registerValueSigned(stack_offset);

    const reg_byte = switch (ptr_offset_reg.bits) {
        8 => 0x45 + (regnum << 3),
        16, 32 => 0x85 + (regnum << 3),
        else => unreachable,
    };

    switch (mode) {
        .SignExtendLoad => try writeStackLoad(output, true, bit_size, reg_byte, regnum),
        .ZeroExtendLoad => try writeStackLoad(output, false, bit_size, reg_byte, regnum),
        .Store => try writeStackStore(output, bit_size, reg_byte, regnum),
    }

    switch (ptr_offset_reg.bits) {
        8 => _ = try output.writeLittle(u8, @truncate(u8, ptr_offset_reg.value)),
        16, 32 => _ = try output.writeLittle(u32, @truncate(u32, ptr_offset_reg.value)),
        else => unreachable,
    }
}

pub fn loadStack(output: *ByteWriter, sign_extend: bool, bit_size: u7, offset: i65) !void {
    try stackRegOp(output, if (sign_extend) .SignExtendLoad else .ZeroExtendLoad, bit_size, -offset - 8, 0);
}

pub fn storeStack(output: *ByteWriter, bit_size: u7, offset: i65) !void {
    try stackRegOp(output, .Store, bit_size, -offset - 8, 0);
}

pub fn compareStack(output: *ByteWriter, bit_size: u7, offset: offset_type) !void {
    unreachable;
}

pub fn bitXorStack(output: *ByteWriter, bit_size: u7, offset: offset_type) !void {
    unreachable;
}

pub fn bitOrStack(output: *ByteWriter, bit_size: u7, offset: offset_type) !void {
    unreachable;
}

pub fn bitAndStack(output: *ByteWriter, bit_size: u7, offset: offset_type) !void {
    unreachable;
}

pub fn jumpRef(output: *ByteWriter, condition: ir.Jump.Condition, target_offset: usize) !void {
    unreachable;
}

pub fn jumpReloc(output: *ByteWriter, condition: ir.Jump.Condition) !Relocation {
    unreachable;
}

pub fn emitAdrReloc(output: *ByteWriter, ref: ir.Xref) !Relocation {
    unreachable;
}

pub fn emitLoadReloc(output: *ByteWriter, sign_extend: bool, bit_size: u7, ref: ir.Xref) !Relocation {
    unreachable;
}

pub fn emitStoreReloc(output: *ByteWriter, bit_size: u7, ref: ir.Xref) !Relocation {
    unreachable;
}

pub fn ptrStoreConstant(output: *ByteWriter, bit_size: u7, value: i65, store_offset: offset_type) std.mem.Allocator.Error!void {
    const value_reg = registerValueSigned(value);

    // If we need more bits to represent this value than we're writng, that's an error.
    if (value_reg.bits > bit_size) {
        unreachable;
    }

    if (bit_size == 64 and value_reg.bits == 64) {
        // Constant writes to qwords take 32 bit imms and are sign extended,
        // we need to split the write into two parts
        try ptrStoreConstant(output, 32, @truncate(i32, value), store_offset);
        try ptrStoreConstant(output, 32, value >> 32, store_offset + 4);
        return;
    }

    const offset_reg = registerValueSigned(store_offset);

    const reg_byte: u8 = switch (offset_reg.bits) {
        8 => 0x40,
        16, 32 => 0x80,
        else => unreachable,
    };

    const value_to_write = @bitCast(u64, @truncate(i64, value));

    // mov [rax + offset], value
    switch (bit_size) {
        8 => _ = try output.writeBytes(&[_]u8{ 0xC6, reg_byte }),
        16 => _ = try output.writeBytes(&[_]u8{ 0x66, 0xC7, reg_byte }),
        32 => _ = try output.writeBytes(&[_]u8{ 0xC7, reg_byte }),
        64 => _ = try output.writeBytes(&[_]u8{ 0x48, 0xC7, reg_byte }),
        else => unreachable,
    }

    switch (offset_reg.bits) {
        8 => _ = try output.writeLittle(u8, @truncate(u8, offset_reg.value)),
        16, 32 => _ = try output.writeLittle(u32, @truncate(u32, offset_reg.value)),
        else => unreachable,
    }

    switch (bit_size) {
        8 => _ = try output.writeLittle(u8, @truncate(u8, value_reg.value)),
        16 => _ = try output.writeLittle(u16, @truncate(u16, value_reg.value)),
        32 => _ = try output.writeLittle(u32, @truncate(u32, value_reg.value)),
        // 32 bit imms for this are always sign extended
        64 => _ = try output.writeLittle(u32, @truncate(u32, value_reg.value)),
        else => unreachable,
    }
}

fn doPtrMov(output: *ByteWriter, bit_size: u7, offset: offset_type, reg_byte_add: u8) !void {
    const offset_reg = registerValueSigned(@intCast(i65, offset));
    const reg_byte: u8 = switch (offset_reg.bits) {
        8 => 0x45 + reg_byte_add,
        16, 32 => 0x85 + reg_byte_add,
        else => unreachable,
    };

    switch (bit_size) {
        8 => _ = try output.writeBytes(&[_]u8{ 0x88, reg_byte }), // mov with [rdi + offset] and al
        16 => _ = try output.writeBytes(&[_]u8{ 0x66, 0x89, reg_byte }), // mov with [rdi + offset] and ax
        32 => _ = try output.writeBytes(&[_]u8{ 0x89, reg_byte }), // mov with [rdi + offset] and eax
        64 => _ = try output.writeBytes(&[_]u8{ 0x48, 0x89, reg_byte }), // mov with [rdi + offset] and rax
        else => unreachable,
    }

    switch (offset_reg.bits) {
        8 => _ = try output.writeLittle(u8, @truncate(u8, offset_reg.value)),
        16, 32 => _ = try output.writeLittle(u32, @truncate(u32, offset_reg.value)),
        else => unreachable,
    }
}

pub fn ptrStore(output: *ByteWriter, bit_size: u7, ptr_stack_offset: i65, store_offset: offset_type) !void {
    // Get the pointer from the stack rdi
    try stackRegOp(output, .ZeroExtendLoad, 64, -ptr_stack_offset - 8, 7);

    if (store_offset == 0) {
        switch (bit_size) {
            8 => _ = try output.writeBytes(&[_]u8{0xAA}), // stosb
            16 => _ = try output.writeBytes(&[_]u8{ 0x66, 0xAB }), // stosw
            32 => _ = try output.writeBytes(&[_]u8{0xAB}), // stosd
            64 => _ = try output.writeBytes(&[_]u8{ 0x48, 0xAB }), // stosq
            else => unreachable,
        }
        return;
    }

    try doPtrMov(output, bit_size, store_offset, 0x02);
}

pub fn ptrLoad(output: *ByteWriter, sign_extend: bool, bit_size: u7, ptr_stack_offset: i65, load_offset: offset_type) !void {
    // Get the pointer from the stack rsi
    try stackRegOp(output, .ZeroExtendLoad, 64, -ptr_stack_offset - 8, 6);

    if (load_offset == 0) {
        switch (bit_size) {
            8 => _ = try output.writeBytes(&[_]u8{0xAC}), // lodsb
            16 => _ = try output.writeBytes(&[_]u8{ 0x66, 0xAD }), // lodsw
            32 => _ = try output.writeBytes(&[_]u8{0xAD}), // lodsd
            64 => _ = try output.writeBytes(&[_]u8{ 0x48, 0xAD }), // lodsq
            else => unreachable,
        }
        return;
    }

    try doPtrMov(output, bit_size, load_offset, 0x00);
}

pub fn storeArgs(output: *ByteWriter, num: usize, offset: offset_type) !void {
    if (num > 6)
        unreachable;

    var base = -@intCast(i65, offset) - 8;

    const regs = [_]u8{
        7, // rdi
        6, // rsi
        2, // rdx
        1, // rcx
        8, // r8
        9, // r9
    };

    for (regs) |r, i| {
        if (num > i) {
            try stackRegOp(output, .Store, 64, base - i * 8, r);
        } else {
            break;
        }
    }
}
