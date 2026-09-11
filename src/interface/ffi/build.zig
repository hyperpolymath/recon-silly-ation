// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// recon-silly-ation FFI Build Configuration (Zig 0.16.0)
//
// Builds the FFI bridge (src/main.zig) as a static library and wires up
// `zig build test` to run both the in-source unit tests and the
// integration test suite.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "recon_silly_ation",
        .root_module = main_module,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // `zig build test` — runs the in-source unit tests in src/main.zig.
    const main_tests = b.addTest(.{
        .root_module = main_module,
    });
    const run_main_tests = b.addRunArtifact(main_tests);

    // ... and the FFI integration test suite in test/integration_test.zig.
    const integration_module = b.createModule(.{
        .root_source_file = b.path("test/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const integration_tests = b.addTest(.{
        .root_module = integration_module,
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);

    const test_step = b.step("test", "Run the FFI unit and integration tests");
    test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_integration_tests.step);
}
