const std = @import("std");

pub const Emulator = struct {
    accum: u64,
};

test "" {
  std.testing.refAllDecls(@This());
}
