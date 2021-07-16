const std = @import("std");

var alloc_impl = std.heap.GeneralPurposeAllocator(.{}){
  .backing_allocator = std.heap.page_allocator,
};

pub const alloc = &alloc_impl.allocator;
