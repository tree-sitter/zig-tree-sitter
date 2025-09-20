const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
    });

    const lib_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const lib = b.addLibrary(.{
        .name = "zig-tree-sitter",
        .root_module = lib_module,
    });
    lib.linkLibrary(core.artifact("tree-sitter"));

    b.installArtifact(lib);

    const module = b.addModule("tree-sitter", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.linkLibrary(lib);

    const docs = b.addObject(.{
        .name = "tree-sitter",
        .root_module = module,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Install generated docs");
    docs_step.dependOn(&install_docs.step);

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const tests = b.addTest(.{
        .root_module = test_module,
    });
    tests.linkLibrary(lib);

    const run_tests = b.addRunArtifact(tests);
    run_tests.skip_foreign_checks = true;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // HACK: fetch tree-sitter-c only for tests (ziglang/zig#19914)
    var args = try std.process.argsWithAllocator(b.allocator);
    defer args.deinit();
    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "test")) {
            if (b.lazyDependency("tree-sitter-c", .{
                .target = target,
                .optimize = optimize,
            })) |dep| {
                const depmod = dep.module("tree-sitter-c");
                depmod.addImport("tree-sitter", module);
                test_module.addImport("tree-sitter-c", depmod);
            }
            break;
        }
    }
}
