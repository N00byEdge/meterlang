const std = @import("std");
const ast = @import("../ast.zig");
const alloc = @import("../main.zig").alloc;

pub const SerializeError = std.io.FixedBufferStream([]u8).WriteError;
pub const DeserializeError = std.io.FixedBufferStream([]const u8).ReadError;

test "" {
  std.testing.refAllDecls(@This());
}

pub fn verify(value: anytype) void {
  const serialize_buffer = alloc.alloc(u8, 0x10000) catch @panic("Alloc serialize_buffer");
  var serialize_stream = std.io.fixedBufferStream(serialize_buffer);
  value.serialize(serialize_stream.writer()) catch @panic("Serializing failed!");

  var deserialize_stream = std.io.fixedBufferStream(serialize_buffer[0..serialize_stream.getPos() catch unreachable]);
  const deserialized = @TypeOf(value).deserialize(deserialize_stream.reader()) catch @panic("Deserializing failed!");
}
