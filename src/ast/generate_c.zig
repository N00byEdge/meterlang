const std = @import("std");
const ast = @import("../ast.zig");
const alloc = @import("../main.zig").alloc;

pub const Error = std.io.FixedBufferStream([]u8).WriteError;

test "" {
  std.testing.refAllDecls(@This());
}

pub fn verify_generates(value: anytype, expected: []const u8) !void {
  const buffer = alloc.alloc(u8, expected.len) catch @panic("Alloc buffer");
  var stream = std.io.fixedBufferStream(buffer);
  value.generate_c(stream.writer()) catch @panic("Generating C failed!");
  try std.testing.expect(std.mem.eql(u8, buffer, expected));
}

pub fn main() !void {

}
