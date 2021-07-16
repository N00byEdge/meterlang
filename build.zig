const std = @import("std");
const builtin = std.builtin;
const Builder = std.build.Builder;

const Testness = enum {
  NotTest,
  Test,
};

fn executable(b: *Builder, name: []const u8, path: []const u8, t: Testness) *std.build.LibExeObjStep {
  const out = switch(t) {
    .NotTest => b.addExecutable(name, path),
    .Test => b.addTest(path),
  };
  switch(t) {
    .NotTest => {
      out.install();
      b.default_step.dependOn(&out.step);
    },
    .Test => { },
  }
  out.setMainPkgPath("src/");

  out.addPackagePath("byte_writer", "src/output/byte_writer.zig");
  out.addPackagePath("codegen", "src/codegen/codegen.zig");
  out.addPackagePath("ir", "src/ir/ir.zig");

  return out;
}

fn addExec(b: *Builder, name: []const u8, path: []const u8) void {
  const e = executable(b, name, path, .NotTest);
  const exec_step = b.step(name, b.fmt("Build {s}", .{name}));
  exec_step.dependOn(&e.step);
  addTest(b, name, path);
}

fn addTest(b: *Builder, name: []const u8, path: []const u8) void {
  const test_name = b.fmt("{s}-tests", .{name});
  const test_e = executable(b, test_name, path, .Test);
  const test_step = b.step(test_name, b.fmt("Run the tests for {s}", .{name}));
  test_step.dependOn(&test_e.step);
  b.default_step.dependOn(&test_e.step);
}

pub fn build(b: *Builder) !void {
  addExec(b, "meter-c", "src/ast/generate_c.zig");
  addTest(b, "meter-emu", "src/ir/emulator.zig");
  addTest(b, "meter-codegen", "src/codegen/codegen.zig");
}
