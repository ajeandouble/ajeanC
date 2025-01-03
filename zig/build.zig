const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{ .name = "ajeanC", .root_source_file = b.path("src/main.zig"), .target = b.standardTargetOptions(.{}), .optimize = b.standardOptimizeOption(.{}), .error_tracing = true });
    // exe.generated_asm("./output.asm");
    b.installArtifact(exe);
}
