const std = @import("std");
const ast = @import("../ast.zig");

const gen_c = @import("generate_c.zig");

pub const StatementType = enum(u8) {
  Compound,
  Expression,
  While,
  For,
  DoWhile,
  If,
};

pub const Statement = union(StatementType) {
  Expression: Expression,
  While: While,
  For: For,
  DoWhile: DoWhile,
  If: If,
  Compound: Compound,

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    try switch(self.*) {
      Expression => |s| s.generate_c(w),
      While => |s| s.generate_c(w),
      For => |s| s.generate_c(w),
      DoWhile => |s| s.generate_c(w),
      If => |s| s.generate_c(w),
      Compound => |s| s.generate_c(w),
    };
  }
};

pub const Compound = struct {
  statements: std.ArrayList(Statement),

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    _ = try w.writeByte('{');
    for(statements.items) |s|
      try s.generate_c(w);
    _ = try w.writeByte('}');
  }
};

pub const Expression = struct {
  expr: ast.Expression.Expression,

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    expr.generate_c(w);
    _ = try w.writeByte(';');
  }
};

pub const While = struct {
  condition: ast.Expression.Expression,
  body: CompoundStatement,

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    _ = try w.write("while(");
    try self.condition.generate_c(w);
    _ = try w.writeByte(')');
    try self.body.generate_c(w);
  }
};

pub const For = struct {
  init: ast.Expression.Expression,
  iter: ast.Expression.Expression,
  wh: WhileStatement,

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    _ = try w.write("for(");
    try self.init.generate_c(w);
    _ = try w.writeByte(';');
    try self.wh.condition.generate_c(w);
    _ = try w.writeByte(';');
    try self.iter.generate_c(w);
    _ = try w.writeByte(')');
    try self.wh.body.generate_c(w);
  }
};

pub const DoWhile = struct {
  body: CompoundStatement,
  condition: ast.Expression.Expression,

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    
  }
};

pub const If = struct {
  condition: ast.Expression.Expression,
  taken: CompoundStatement,
  notTaken: ?CompoundStatement,

  pub fn generate_c(self: *const @This(), w: anytype) gen_c.Error!void {
    
  }
};
