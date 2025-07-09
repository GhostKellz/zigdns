const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigdns",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // TODO: Re-enable ZQUIC and ZCRYPTO when dependencies are properly added
    // const zquic = b.dependency("zquic", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // exe.root_module.addImport("zquic", zquic.module("zquic"));
    
    // const zcrypto = b.dependency("zcrypto", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // exe.root_module.addImport("zcrypto", zcrypto.module("zcrypto"));

    // Add cache.zig for LRU cache functionality
    const cache = b.dependency("cache", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("cache", cache.module("cache"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    b.step("run", "Run the app").dependOn(&run_cmd.step);

    // Add test step
    const exe_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
