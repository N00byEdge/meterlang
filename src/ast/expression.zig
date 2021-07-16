const std = @import("std");
const ast = @import("../ast.zig");
const alloc = @import("../main.zig").alloc;

const gen_c = @import("generate_c.zig");
const serialize = @import("serialize.zig");

pub const ExpressionType = enum(u8) {
  // Interesting expressions
  Identifier,
  Declaration,

  // Boring unary expressions
  Preinc,
  Postinc,
  Predec,
  Postdec,

  // Boring binary expressions
  Assignment,
  AddEq,
  Add,
  BitandEq,
  Bitand,
  BitorEq,
  Bitor,
  EqualsComparison,
  SubEq,
  Sub,
};

pub const Expression = union(ExpressionType) {
  Identifier: Identifier,
  Declaration: Declaration,

  Preinc: Preinc,
  Postinc: Postinc,
  Predec: Predec,
  Postdec: Postdec,

  Assignment: Assignment,
  AddEq: AddEq,
  Add: Add,
  BitandEq: BitandEq,
  Bitand: Bitand,
  BitorEq: BitorEq,
  Bitor: Bitor,
  EqualsComparison: EqualsComparison,
  SubEq: SubEq,
  Sub: Sub,

  const TagType = @typeInfo(@This()).Union.tag_type.?;

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    inline for(@typeInfo(TagType).Enum.fields) |tt| {
      switch(self.*) {
          @intToEnum(TagType, tt.value) => |expr| {
          try expr.generate_c(w);
        },
        else => {},
      }
    }
  }

  pub fn serialize(self: *const @This(), w: anytype) serialize.SerializeError!void {
    inline for(@typeInfo(TagType).Enum.fields) |tt| {
      switch(self.*) {
          @intToEnum(TagType, tt.value) => |expr| {
          try expr.serialize(w);
        },
        else => {},
      }
    }
  }
};

fn BinaryExpr(comptime c_op: []const u8) type {
  return struct {
    lhs: *Expression,
    rhs: *Expression,

    pub fn make(lhs: Expression, rhs: Expression) !@This() {
      const ptr = try alloc.alloc(Expression, 2);
      ptr[0] = lhs;
      ptr[1] = rhs;

      return @This(){
        .lhs = &ptr[0],
        .rhs = &ptr[1],
      };
    }

    pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
      _ = try w.writeByte('(');
      try self.lhs.generate_c(w);
      _ = try w.write(c_op);
      try self.rhs.generate_c(w);
      _ = try w.writeByte(')');
    }

    pub fn serialize(self: *const @This(), w: anytype) serialize.SerializeError!void {
      try self.lhs.serialize(w);
      try self.rhs.serialize(w);
    }

    pub fn deserialize(self: *const @This(), r: anytype) serialize.DeserializeError!@This() {
      const lhs = Expression.deserialize(r);
      const rhs = Expression.deserialize(r);
      return try make(lhs, rhs);
    }
  };
}

test "BinaryExpr EqualsComparison gen_c" {
  try gen_c.verify_generates(
    try BinaryExpr("==").make(
      .{ .Identifier = Identifier.make("i") },
      .{ .Identifier = Identifier.make("j") },
    ), "(i==j)");
}

// test "BinaryExpr verify serialize" {
//   serialize.verify(
//     try BinaryExpr("==").make(
//       .{ .Identifier = Identifier.make("i") },
//       .{ .Identifier = Identifier.make("j") },
//     )
//   );
// }

test "BinaryExpr BitandEq gen_c" {
  try gen_c.verify_generates(
    try BinaryExpr("&=").make(
      .{ .Identifier = Identifier.make("a") },
      .{ .Identifier = Identifier.make("b") },
    ), "(a&=b)");
}

test "BinaryExpr Bitand gen_c" {
  try gen_c.verify_generates(
    try BinaryExpr("&").make(
      .{ .Identifier = Identifier.make("j") },
      .{ .Identifier = Identifier.make("i") },
    ), "(j&i)");
}

const UnaryOrder = enum {
  Prefix,
  Postfix,
};

fn UnaryExpr(comptime c_op: []const u8, comptime order: UnaryOrder) type {
  return struct {
    operand: *Expression,

    pub fn make(operand: Expression) !@This() {
      const ptr = try alloc.alloc(Expression, 1);
      ptr[0] = operand;

      return @This(){
        .operand = &ptr[0],
      };
    }

    pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
      _ = try w.write("(" ++ if(order == .Prefix) c_op else "");
      try self.operand.generate_c(w);
      _ = try w.write((if(order == .Postfix) c_op else "") ++ ")");
    }
  };
}

test "UnaryExpr prefix op gen_c" {
  try gen_c.verify_generates(
    try UnaryExpr("++", .Prefix).make(
      .{ .Identifier = Identifier.make("i") },
    ), "(++i)");
}

test "UnaryExpr postfix op gen_c" {
  try gen_c.verify_generates(
    try UnaryExpr("--", .Postfix).make(
      .{ .Identifier = Identifier.make("j") },
    ), "(j--)");
}

pub const Identifier = struct {
  // This of course needs to be more sensible later
  identifier_name: []const u8,

  pub fn make(str: []const u8) @This() {
    return .{
      .identifier_name = str,
    };
  }

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    _ = try w.write(self.identifier_name);
  }
};

pub const Declaration = struct {
  ident: Identifier,
  decltype: *Expression,

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    try self.decltype.generate_c(w);
    _ = try w.writeByte(' ');
    try self.ident.generate_c(w);
  }
};

pub const Preinc = UnaryExpr("++", .Prefix);
pub const Postinc = UnaryExpr("++", .Postfix);
pub const Predec = UnaryExpr("--", .Prefix);
pub const Postdec = UnaryExpr("--", .Postfix);

pub const EqualsComparison = BinaryExpr("==");
pub const Assignment = BinaryExpr("=");
pub const AddEq = BinaryExpr("+=");
pub const Add = BinaryExpr("+");
pub const BitandEq = BinaryExpr("&=");
pub const Bitand = BinaryExpr("&");
pub const BitorEq = BinaryExpr("|=");
pub const Bitor = BinaryExpr("|");
pub const SubEq = BinaryExpr("+=");
pub const Sub = BinaryExpr("+");
