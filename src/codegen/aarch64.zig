const ByteWriter = @import("byte_writer").ByteWriter;
const std = @import("std");
const ir = @import("ir");

test "" {
    std.testing.refAllDecls(@This());
}

pub const ptr_type = u64;
pub const sptr_type = i65;
pub const offset_type = u12;

pub const name = "aarch64";

const RelocationType = enum {
    cond_branch_reg,
    imm_mov_lsl0,
    imm_mov_lsl16,
    imm_mov_lsl32,
    imm_mov_lsl48,
};

const log = std.log.scoped(.aarch64);

pub const Relocation = struct {
    reltype: RelocationType,
    bytes: ByteWriter.Ref,

    pub fn isRelative(self: *const @This()) bool {
        return switch (self.reltype) {
            .imm_mov_lsl0, .imm_mov_lsl16, .imm_mov_lsl32, .imm_mov_lsl48 => false,
            .cond_branch_reg => true,
        };
    }

    pub fn applyAbsolute(self: *const @This(), output: *ByteWriter, target_offset: usize, base_addr: ptr_type) void {
        return switch (self.reltype) {
            .imm_mov_lsl0 => {},
            .imm_mov_lsl16 => {},
            .imm_mov_lsl32 => {},
            .imm_mov_lsl48 => {},
            else => unreachable,
        };
    }

    pub fn applyRelative(self: *const @This(), output: *ByteWriter, target_offset: i65) void {
        const bytes = output.bytes(self.bytes)[0..4];
        const value = std.mem.readIntLittle(u32, bytes);
        var or_val: u32 = undefined;

        const rel_addr = target_offset - self.bytes.offset;

        switch (self.reltype) {
            .cond_branch_reg => or_val = @intCast(u32, @bitCast(u19, @intCast(i19, @divExact(rel_addr, 4)))) << 5,
            else => unreachable,
        }

        std.mem.writeIntLittle(u32, bytes, value | or_val);
    }
};

fn rawMov(rd: u5, imm: u16, lsl: MovLSL, keep: MovKeep, negate: MovNegation, op_size: MovOpSize) u32 {
    // zig fmt: off
    return 0x12800000
        | @intCast(u32, rd) << 0
        | @intCast(u32, imm) << 5
        | @intCast(u32, @enumToInt(lsl)) << 21
        | @intCast(u32, @enumToInt(keep)) << 29
        | @intCast(u32, @enumToInt(negate)) << 30
        | @intCast(u32, @enumToInt(op_size)) << 31
    ;
    // zig fmt: on
}

const MovLSL = enum(u2) {
    lsl0 = 0,
    lsl16 = 1,
    lsl32 = 2,
    lsl48 = 3,
};

const MovKeep = enum(u1) {
    AffectAllOthers = 0,
    KeepAllOthers = 1,
};

const MovNegation = enum(u1) {
    Negate = 0,
    DoNotNegate = 1,
};

const MovOpSize = enum(u1) {
    W = 0,
    X = 1,
};

fn movz(rd: u5, imm: u16, lsl: MovLSL, op_size: MovOpSize) u32 {
    return rawMov(rd, imm, lsl, .AffectAllOthers, .DoNotNegate, op_size);
}

fn movk(rd: u5, imm: u16, lsl: MovLSL, op_size: MovOpSize) u32 {
    return rawMov(rd, imm, lsl, .KeepAllOthers, .DoNotNegate, op_size);
}

fn movn(rd: u5, imm: u16, lsl: MovLSL, op_size: MovOpSize) u32 {
    return rawMov(rd, imm, lsl, .AffectAllOthers, .Negate, op_size);
}

fn strLdr(rt: u6, rn: u6, offset: u12, mode: LDRSTRMode, mem_size: LDRSTRMemorySize) u32 {
    // zig fmt: off
    return 0x39000000
        | @intCast(u32, rt) << 0
        | @intCast(u32, rn) << 5
        | @intCast(u32, offset) << 10
        | @intCast(u32, @enumToInt(mode)) << 22
        | @intCast(u32, @enumToInt(mem_size)) << 30
    ;
    // zig fmt: on
}

const LDRSTRMode = enum(u2) {
    Store = 0,
    LoadZeroExtendX = 1,
    LoadSignExtendW = 2,
    LoadSignExtendX = 3,
};

const LDRSTRMemorySize = enum(u2) {
    B = 0,
    H = 1,
    W = 2,
    X = 3,

    fn toSignedLoadMode(self: @This()) LDRSTRMode {
        switch (self) {
            .W => return .LoadSignExtendW,
            .X => return .LoadSignExtendX,
            else => unreachable,
        }
    }
};

fn strb(rt: u5, rn: u5, offset: u12) u32 {
    return str(rt, rn, offset, .B);
}

fn strh(rt: u5, rn: u5, offset: u12) u32 {
    return str(rt, rn, offset, .H);
}

test "small stores" {
    try std.testing.expect(strb(0, 0, 0) == 0x39000000);
    try std.testing.expect(strh(0, 0, 0) == 0x79000000);
}

fn ldrb(rt: u5, rn: u5, offset: u12) u32 {
    return strLdr(rt, rn, offset, .LoadZeroExtendX, .B);
}

fn ldrh(rt: u5, rn: u5, offset: u12) u32 {
    return strLdr(rt, rn, offset, .LoadZeroExtendX, .H);
}

test "small loads" {
    try std.testing.expect(ldrb(0, 0, 0) == 0x39400000);
    try std.testing.expect(ldrh(0, 0, 0) == 0x79400000);
}

fn ldrsb(rt: u5, rn: u5, offset: u12, source_size: LDRSTRMemorySize) u32 {
    return strLdr(rt, rn, offset, source_size.toSignedLoadMode(), .B);
}

fn ldrsh(rt: u5, rn: u5, offset: u12, source_size: LDRSTRMemorySize) u32 {
    return strLdr(rt, rn, offset, source_size.toSignedLoadMode(), .H);
}

fn ldrsw(rt: u5, rn: u5, offset: u12) u32 {
    return strLdr(rt, rn, offset, .LoadSignExtendX, .W);
}

test "sign extended loads" {
    // @TODO: These apparently are broken. Why??
    //try std.testing.expect(ldrsb(0, 0, 0, .W) == 0x39C00000);
    //try std.testing.expect(ldrsb(0, 0, 0, .X) == 0x39800000);
    //try std.testing.expect(ldrsh(0, 0, 0, .W) == 0x79C00000);
    //try std.testing.expect(ldrsh(0, 0, 0, .X) == 0x79800000);
    //try std.testing.expect(ldrsw(0, 0, 0) == 0xB9800000);
}

fn str(rt: u5, rn: u5, offset: u12, target_size: LDRSTRMemorySize) u32 {
    return strLdr(rt, rn, offset, .Store, target_size);
}

test "str" {
    try std.testing.expect(str(0, 0, 0, .W) == 0xB9000000);
    try std.testing.expect(str(0, 0, 0, .X) == 0xF9000000);
}

fn ldr(rt: u5, rn: u5, offset: u12, source_size: LDRSTRMemorySize) u32 {
    return strLdr(rt, rn, offset, .LoadZeroExtendX, source_size);
}

test "ldr" {
    try std.testing.expect(ldr(0, 0, 0, .W) == 0xB9400000);
    try std.testing.expect(ldr(0, 0, 0, .X) == 0xF9400000);
}

fn ldpStp(rt: u5, rt2: u5, rn: u5, offset: u7, op_size: LDPSTPOpSize, mode: LDPSTPMode) u32 {
    // zig fmt: off
    return 0x29000000
        | @intCast(u32, @enumToInt(op_size)) << 30
        | @intCast(u32, @enumToInt(mode)) << 22
        | @intCast(u32, offset) << 15
        | @intCast(u32, rt2) << 10
        | @intCast(u32, rn) << 5
        | @intCast(u32, rt) << 0
    ;
    // zig fmt: on
}

const LDPSTPMode = enum(u1) {
    Store = 0,
    Load = 1,
};

const LDPSTPOpSize = enum(u2) {
    W = 0,
    X = 2,
};

fn ldp(rt: u5, rt2: u5, rn: u5, offset: u7, op_size: LDPSTPOpSize) u32 {
    return ldpStp(rt, rt2, rn, offset, op_size, .Load);
}

fn stp(rt: u5, rt2: u5, rn: u5, offset: u7, op_size: LDPSTPOpSize) u32 {
    return ldpStp(rt, rt2, rn, offset, op_size, .Store);
}

fn subAdd(rd: u5, rn: u5, imm: u12, op_size: SubAddOpSize, mode: SubAddMode, sign: SubAddSignedness) u32 {
    // zig fmt: off
    return 0x11000000 // Opcode
        | @intCast(u32, @enumToInt(op_size)) << 31
        | @intCast(u32, @enumToInt(mode)) << 30
        | @intCast(u32, @enumToInt(sign)) << 29
        | @intCast(u32, imm) << 10
        | @intCast(u32, rn) << 5
        | @intCast(u32, rd) << 0
    ;
    // zig fmt: on
}

fn subAddRegs(rd: u5, rn: u5, rm: u5, op_size: SubAddOpSize, mode: SubAddMode, sign: SubAddSignedness) u32 {
    // zig fmt: off
    return 0x0B000000 // Opcode
        | @intCast(u32, @enumToInt(op_size)) << 31
        | @intCast(u32, @enumToInt(mode)) << 30
        | @intCast(u32, @enumToInt(sign)) << 29
        | @intCast(u32, rm) << 16
        | @intCast(u32, rn) << 5
        | @intCast(u32, rd) << 0
    ;
    // zig fmt: on
}

const SubAddOpSize = enum(u1) {
    W = 0,
    X = 1,
};

const SubAddMode = enum(u1) {
    Add = 0,
    Sub = 1,
};

const SubAddSignedness = enum(u1) {
    Unsigned = 0,
    Signed = 1,
};

fn sub(rd: u5, rn: u5, imm: u12, op_size: SubAddOpSize) u32 {
    return subAdd(rd, rn, imm, op_size, .Sub, .Unsigned);
}

fn subRegs(rd: u5, rn: u5, rm: u5, op_size: SubAddOpSize) u32 {
    return subAddRegs(rd, rn, rm, op_size, .Sub, .Unsigned);
}

fn add(rd: u5, rn: u5, imm: u12, op_size: SubAddOpSize) u32 {
    return subAdd(rd, rn, imm, op_size, .Add, .Unsigned);
}

fn addRegs(rd: u5, rn: u5, rm: u5, op_size: SubAddOpSize) u32 {
    return subAddRegs(rd, rn, rm, op_size, .Add, .Unsigned);
}

const Decomposed = struct {
    lsl0: ?u16,
    lsl16: ?u16,
    lsl32: ?u16,
    lsl48: ?u16,
    negative: bool,
};

fn decomposeInt(value: i65, shift: u6, negative: bool) ?u16 {
    const eql: u16 = if (negative) 0xFFFF else 0;

    const extracted = @bitCast(u16, @truncate(i16, value >> shift));
    if (extracted == eql) return null;

    if (negative) return ~extracted;
    return extracted;
}

fn decompose(value: i65) Decomposed {
    var result: Decomposed = undefined;
    result.negative = value < 0;

    result.lsl0 = decomposeInt(value, 0, result.negative);
    result.lsl16 = decomposeInt(value, 16, result.negative);
    result.lsl32 = decomposeInt(value, 32, result.negative);
    result.lsl48 = decomposeInt(value, 48, result.negative);

    return result;
}

fn loadDecomposed(output: *ByteWriter, rd: u5, value: Decomposed) !void {
    var first = true;

    if (value.lsl0) |val| {
        if (first) {
            if (value.negative) {
                _ = try output.writeLittle(u32, movn(rd, val, .lsl0, .X));
            } else {
                _ = try output.writeLittle(u32, movz(rd, val, .lsl0, .X));
            }
        } else {
            _ = try output.writeLittle(u32, movk(rd, val, .lsl0, .X));
        }
        first = false;
    }

    if (value.lsl16) |val| {
        if (first) {
            if (value.negative) {
                _ = try output.writeLittle(u32, movn(rd, val, .lsl16, .X));
            } else {
                _ = try output.writeLittle(u32, movz(rd, val, .lsl16, .X));
            }
        } else {
            _ = try output.writeLittle(u32, movk(rd, val, .lsl16, .X));
        }
        first = false;
    }

    if (value.lsl32) |val| {
        if (first) {
            if (value.negative) {
                _ = try output.writeLittle(u32, movn(rd, val, .lsl32, .X));
            } else {
                _ = try output.writeLittle(u32, movz(rd, val, .lsl32, .X));
            }
        } else {
            _ = try output.writeLittle(u32, movk(rd, val, .lsl32, .X));
        }
        first = false;
    }

    if (value.lsl48) |val| {
        if (first) {
            if (value.negative) {
                _ = try output.writeLittle(u32, movn(rd, val, .lsl48, .X));
            } else {
                _ = try output.writeLittle(u32, movz(rd, val, .lsl48, .X));
            }
        } else {
            _ = try output.writeLittle(u32, movk(rd, val, .lsl48, .X));
        }
        first = false;
    }

    // Value was just 0
    if (first) {
        _ = try output.writeLittle(u32, movz(rd, 0, .lsl0, .X));
        return;
    }
}

pub fn prepareFunction(output: *ByteWriter) !ByteWriter.Ref {
    // STP X29, X30, [SP, #-0x20]!
    _ = try output.writeLittle(u32, 0xA9BE7BFD);

    // MOV X29, SP
    _ = try output.writeLittle(u32, 0x910003FD);

    // SUB SP, SP, #value
    // We leave this entirely undefined until the fixup
    return output.writeLittle(u32, undefined);
}

pub fn endFunction(output: *ByteWriter, fixup: ByteWriter.Ref, used_stack_bytes: offset_type) !void {
    std.mem.writeIntLittle(u32, output.bytes(fixup)[0..4], sub(31, 31, used_stack_bytes, .X));

    // MOV SP, X29
    _ = try output.writeLittle(u32, 0x910003BF);

    // LDP X29, X30, [SP], #0x20
    _ = try output.writeLittle(u32, 0xA8C27BFD);

    // RET
    _ = try output.writeLittle(u32, 0xD65F03C0);
}

pub fn loadConstant(output: *ByteWriter, value: i65) !void {
    try loadDecomposed(output, 0, decompose(value));
}

pub fn addConstant(output: *ByteWriter, value: i65) !void {
    // Does it fit in a add/sub immediate?
    if (value < 0) {
        if (-value <= std.math.maxInt(u12)) {
            _ = try output.writeLittle(u32, sub(0, 0, @intCast(u12, -value), .X));
            return;
        }
    } else {
        if (value <= std.math.maxInt(u12)) {
            _ = try output.writeLittle(u32, add(0, 0, @intCast(u12, value), .X));
            return;
        }
    }

    // Load the entire value into X1
    try loadDecomposed(output, 1, decompose(value));

    // ADD X0, X0, X1
    _ = try output.writeLittle(u32, addRegs(0, 0, 1, .X));
}

pub fn compareConstant(output: *ByteWriter, value: i65) !void {
    unreachable;
}

pub fn adrStack(output: *ByteWriter, offset: offset_type) !void {
    unreachable;
}

pub fn loadStack(output: *ByteWriter, sign_extend: bool, bit_size: u7, offset: i65) !void {
    switch (bit_size) {
        8 => _ = try output.writeLittle(u32, ldr(0, 31, @intCast(u12, offset), .B)),
        16 => _ = try output.writeLittle(u32, ldr(0, 31, @intCast(u12, offset), .H)),
        32 => _ = try output.writeLittle(u32, ldr(0, 31, @intCast(u12, offset), .W)),
        64 => _ = try output.writeLittle(u32, ldr(0, 31, @intCast(u12, offset), .X)),
        else => unreachable,
    }
}

pub fn storeStack(output: *ByteWriter, bit_size: u7, offset: i65) !void {
    switch (bit_size) {
        32 => _ = try output.writeLittle(u32, str(0, 31, @intCast(u12, offset), .W)),
        64 => _ = try output.writeLittle(u32, str(0, 31, @intCast(u12, offset), .X)),
        else => unreachable,
    }
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
    try loadDecomposed(output, 1, decompose(value));
    switch (bit_size) {
        8 => _ = try output.writeLittle(u32, str(1, 0, @intCast(u12, store_offset), .B)),
        16 => _ = try output.writeLittle(u32, str(1, 0, @intCast(u12, store_offset), .H)),
        32 => _ = try output.writeLittle(u32, str(1, 0, @intCast(u12, store_offset), .W)),
        64 => _ = try output.writeLittle(u32, str(1, 0, @intCast(u12, store_offset), .X)),
        else => unreachable,
    }
}

pub fn ptrStore(output: *ByteWriter, bit_size: u7, ptr_stack_offset: i65, store_offset: offset_type) !void {
    // Load the pointer from the stack into X1
    _ = try output.writeLittle(u32, ldr(1, 31, @intCast(u12, ptr_stack_offset), .X));

    // Store X0 to [X1]
    switch (bit_size) {
        8 => _ = try output.writeLittle(u32, str(0, 1, store_offset, .B)),
        16 => _ = try output.writeLittle(u32, str(0, 1, store_offset, .H)),
        32 => _ = try output.writeLittle(u32, str(0, 1, store_offset, .W)),
        64 => _ = try output.writeLittle(u32, str(0, 1, store_offset, .X)),
        else => unreachable,
    }
}

pub fn ptrLoad(output: *ByteWriter, sign_extend: bool, bit_size: u7, ptr_stack_offset: i65, load_offset: offset_type) !void {
    // Load the pointer from the stack into X1
    _ = try output.writeLittle(u32, ldr(1, 31, @intCast(u12, ptr_stack_offset), .X));

    const mode: LDRSTRMode = if (sign_extend) .LoadSignExtendX else .LoadZeroExtendX;

    // Load X0 from [X1]
    switch (bit_size) {
        8 => _ = try output.writeLittle(u32, strLdr(0, 1, @intCast(u12, ptr_stack_offset), mode, .B)),
        16 => _ = try output.writeLittle(u32, strLdr(0, 1, @intCast(u12, ptr_stack_offset), mode, .H)),
        32 => _ = try output.writeLittle(u32, strLdr(0, 1, @intCast(u12, ptr_stack_offset), mode, .W)),
        64 => _ = try output.writeLittle(u32, strLdr(0, 1, @intCast(u12, ptr_stack_offset), .LoadZeroExtendX, .X)),
        else => unreachable,
    }
}

pub fn storeArgs(output: *ByteWriter, num: usize, offset: offset_type) !void {
    if (num > 8) {
        unreachable;
    }

    var pushed: u5 = 0;
    while (pushed < num) {
        const current_offset = offset + pushed * 0x10;
        if (pushed < num + 1 and current_offset <= std.math.maxInt(u7)) {
            _ = try output.writeLittle(u32, stp(pushed, pushed + 1, 31, @intCast(u7, current_offset), .X));
            pushed += 2;
        } else {
            _ = try output.writeLittle(u32, str(pushed, 31, current_offset, .X));
            pushed += 1;
        }
    }
}
