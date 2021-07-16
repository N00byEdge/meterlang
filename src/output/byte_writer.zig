const std = @import("std");

pub const ByteWriter = struct {
    pub const Ref = struct {
        offset: usize,
        size: usize,
    };

    storage: std.ArrayList(u8),

    pub fn init(alloc: *std.mem.Allocator) @This() {
        return .{
            .storage = std.ArrayList(u8).init(alloc),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.storage.deinit();
    }

    pub fn writeBytes(self: *@This(), value: []const u8) !Ref {
        const offset = self.storage.items.len;
        try self.storage.appendSlice(value);

        return Ref{
            .offset = offset,
            .size = value.len,
        };
    }

    pub fn bytes(self: *@This(), r: Ref) []u8 {
        return self.storage.items[r.offset..][0..r.size];
    }

    pub fn currentOffset(self: *const @This()) usize {
        return self.storage.items.len;
    }

    pub fn writeEndian(self: *@This(), comptime T: type, value: T, endian: std.builtin.Endian) !Ref {
        var buffer = [_]u8{undefined} ** @sizeOf(T);
        std.mem.writeInt(T, buffer[0..@sizeOf(T)], value, endian);
        return self.writeBytes(buffer[0..]);
    }

    pub fn writeLittle(self: *@This(), comptime T: type, value: T) !Ref {
        return self.writeEndian(T, value, .Little);
    }

    pub fn writeBig(self: *@This(), comptime T: type, value: T) !Ref {
        return self.writeEndian(T, value, .Big);
    }
};
