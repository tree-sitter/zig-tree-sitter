const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const wasm = b.option(bool, "enable-wasm", "Enable Wasm support") orelse false;

    const options = b.addOptions();
    options.addOption(@TypeOf(wasm), "wasm_enabled", wasm);

    const core = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
        .@"enable-wasm" = wasm,
    });

    const lib_mod = b.addModule("tree-sitter", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib_mod.linkLibrary(core.artifact("tree-sitter"));
    lib_mod.addOptions("build_options", options);

    const lib = b.addStaticLibrary(.{
        .name = "zig-tree-sitter",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Install generated docs");
    docs_step.dependOn(&install_docs.step);

    const test_mod = b.addModule("tests", .{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.linkLibrary(lib);
    test_mod.addOptions("build_options", options);

    const tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // HACK: fetch tree-sitter-c only for tests (ziglang/zig#19914)
    var args = try std.process.argsWithAllocator(b.allocator);
    defer args.deinit();
    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "test")) {
            if (b.lazyDependency("tree-sitter-c", .{})) |dep| {
                const dep_lib = dep.builder.addStaticLibrary(.{
                    .name = "tree-sitter-c",
                    .target = target,
                    .optimize = optimize,
                    .link_libc = true,
                });
                dep_lib.addIncludePath(dep.path("src"));
                dep_lib.addCSourceFile(.{
                    .file = dep.path("src/parser.c"),
                });
                tests.linkLibrary(dep_lib);
            }
            break;
        }
    }
}
