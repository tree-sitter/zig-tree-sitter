const build = @import("build");
const std = @import("std");
const testing = std.testing;
const ts = @import("root.zig");
const c = @import("tree-sitter-c");
const Language = ts.Language;

test "Language" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    try testing.expectEqual(15, language.abiVersion());
    try testing.expect(language.semanticVersion() != null);
    try testing.expect(language.nodeKindCount() > 1);
    try testing.expect(language.fieldCount() > 1);
    try testing.expect(language.parseStateCount() > 1);
    try testing.expect(language.fieldIdForName("body") > 0);
    try testing.expect(language.fieldNameForId(1) != null);
    try testing.expectEqual(161, language.idForNodeKind("translation_unit", true));
    try testing.expectEqualStrings("identifier", language.nodeKindForId(1) orelse "");
    try testing.expect(language.nodeKindIsNamed(1));
    try testing.expect(language.nodeKindIsVisible(1));
    try testing.expect(!language.nodeKindIsSupertype(1));
    try testing.expect(language.nextState(1, 161) > 1);
    try testing.expect(!language.isWasm());

    const copy = language.dupe();
    try testing.expectEqual(language, copy);
    copy.destroy();
}

test "LookaheadIterator" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const state = language.nextState(1, 161);
    const lookahead = language.lookaheadIterator(state).?;
    defer lookahead.destroy();

    try testing.expectEqual(language, lookahead.language());
    try testing.expectEqual(0xFFFF, lookahead.currentSymbol());
    try testing.expectEqualStrings("ERROR", lookahead.currentSymbolName());

    try testing.expect(lookahead.next());
    try testing.expectEqual(160, lookahead.currentSymbol());
    try testing.expectEqualStrings("comment", lookahead.currentSymbolName());

    try testing.expect(lookahead.next());
    try testing.expectEqual(0, lookahead.currentSymbol());
    try testing.expectEqualStrings("end", lookahead.currentSymbolName());

    try testing.expect(!lookahead.next());
    try testing.expect(lookahead.resetState(state));

    try testing.expect(lookahead.next());
    try testing.expect(lookahead.reset(language, state));
}

test "Parser" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    try testing.expectEqual(language, parser.getLanguage());
    try testing.expectEqual(null, parser.getLogger().log);

    try testing.expectEqualSlices(ts.Range, &.{.{}}, parser.getIncludedRanges());
    try testing.expectError(error.IncludedRangesError, parser.setIncludedRanges(&.{ .{ .start_byte = 1 }, .{} }));

    // TODO: more tests
}

test "Tree" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    const tree = parser.parseString("int main() {}", null).?;
    defer tree.destroy();
    try testing.expectEqual(language, tree.getLanguage());
    try testing.expectEqual(13, tree.rootNode().endByte());
    try testing.expectEqual(3, tree.rootNodeWithOffset(3, .{ .row = 0, .column = 3 }).startByte());

    var ranges = try tree.getIncludedRanges(testing.allocator);
    var range: ts.Range = .{
        .start_point = .{ .row = 0, .column = 0 },
        .end_point = .{ .row = 0xFFFFFFFF, .column = 0xFFFFFFFF },
        .start_byte = 0,
        .end_byte = 0xFFFFFFFF,
    };
    try testing.expectEqualSlices(ts.Range, &.{range}, ranges);
    testing.allocator.free(ranges);

    const old_tree = tree.dupe();
    try testing.expect(tree != old_tree);
    defer old_tree.destroy();

    old_tree.edit(.{
        .start_byte = 0,
        .start_point = .{ .row = 0, .column = 0 },
        .old_end_byte = 13,
        .new_end_byte = 9,
        .old_end_point = .{ .row = 0, .column = 13 },
        .new_end_point = .{ .row = 0, .column = 9 },
    });
    const new_tree = parser.parseStringEncoding("main() {}", old_tree, .utf8).?;
    defer new_tree.destroy();
    range = .{
        .start_point = .{ .row = 0, .column = 0 },
        .end_point = .{ .row = 0, .column = 9 },
        .start_byte = 0,
        .end_byte = 9,
    };
    ranges = try old_tree.getChangedRanges(testing.allocator, new_tree);
    try testing.expectEqualSlices(ts.Range, &.{range}, ranges);
    testing.allocator.free(ranges);
}
//
test "TreeCursor" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    const tree = parser.parseStringEncoding("int main() {}", null, .utf8).?;
    defer tree.destroy();
    const root_node = tree.rootNode();

    var cursor = root_node.walk();
    defer cursor.destroy();

    var node = cursor.node();
    try testing.expect(node.eql(root_node));
    try testing.expectEqual(node, cursor.node());

    var copy = cursor.dupe();
    try testing.expect(cursor.id != copy.id);
    try testing.expectEqual(cursor.tree, copy.tree);

    cursor.resetTo(&copy);
    try testing.expectEqual(copy.node(), cursor.node());
    copy.destroy();

    try testing.expect(cursor.gotoFirstChild());
    try testing.expectEqualStrings("function_definition", cursor.node().kind());
    try testing.expectEqual(1, cursor.depth());

    try testing.expect(cursor.gotoLastChild());
    try testing.expectEqualStrings("compound_statement", cursor.node().kind());
    try testing.expectEqualStrings("body", cursor.fieldName().?);

    try testing.expect(cursor.gotoParent());
    try testing.expectEqualStrings("function_definition", cursor.node().kind());
    try testing.expectEqual(0, cursor.fieldId());

    try testing.expect(!cursor.gotoNextSibling());
    try testing.expect(!cursor.gotoPreviousSibling());

    cursor.gotoDescendant(2);
    try testing.expectEqual(2, cursor.descendantIndex());
    cursor.reset(root_node);

    try testing.expectEqual(0, cursor.gotoFirstChildForByte(1));
    try testing.expectEqual(1, cursor.gotoFirstChildForPoint(.{ .row = 0, .column = 5 }));
    try testing.expectEqualStrings("declarator", cursor.fieldName().?);
}

test "Node" {
    ts.setAllocator(testing.allocator);
    defer ts.setAllocator(null);

    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    const tree = parser.parseStringEncoding("int main() {}", null, .utf8).?;
    defer tree.destroy();
    var node = tree.rootNode();

    try testing.expectEqual(tree, node.tree);
    try testing.expectEqual(tree.getLanguage(), node.getLanguage());

    try testing.expectEqual(161, node.kindId());
    try testing.expectEqual(161, node.grammarId());
    try testing.expectEqualStrings("translation_unit", node.kind());
    try testing.expectEqualStrings("translation_unit", node.grammarKind());

    try testing.expect(node.isNamed());
    try testing.expect(!node.isExtra());
    try testing.expect(!node.isError());
    try testing.expect(!node.isMissing());

    try testing.expectEqual(0, node.parseState());
    try testing.expectEqual(0, node.nextParseState());

    try testing.expectEqual(0, node.startByte());
    try testing.expectEqual(13, node.endByte());
    try testing.expectEqual(0, node.startPoint().column);
    try testing.expectEqual(13, node.endPoint().column);

    const range = node.range();
    try testing.expectEqual(0, range.start_byte);
    try testing.expectEqual(13, range.end_byte);
    try testing.expectEqual(0, range.start_point.column);
    try testing.expectEqual(13, range.end_point.column);

    try testing.expectEqual(1, node.childCount());
    try testing.expectEqual(1, node.namedChildCount());
    try testing.expectEqual(11, node.descendantCount());

    node = node.child(0).?;
    try testing.expectEqual(tree.rootNode(), node.parent());
    try testing.expectEqualStrings("function_declarator", node.namedChild(1).?.kind());
    try testing.expectEqual(null, node.childByFieldId(1));
    try testing.expectEqualStrings("primitive_type", node.childByFieldName("type").?.kind());

    try testing.expectEqualStrings("function_declarator", node.child(0).?.nextSibling().?.kind());
    try testing.expectEqualStrings("function_declarator", node.child(0).?.nextNamedSibling().?.kind());
    try testing.expectEqualStrings("function_declarator", node.child(2).?.prevSibling().?.kind());
    try testing.expectEqualStrings("function_declarator", node.child(2).?.prevNamedSibling().?.kind());

    try testing.expectEqual(node, tree.rootNode().childWithDescendant(node));
    try testing.expectEqualStrings("{", node.descendantForByteRange(11, 12).?.kind());
    try testing.expectEqualStrings("compound_statement", node.namedDescendantForByteRange(11, 12).?.kind());

    const points: [2]ts.Point = .{ .{ .row = 0, .column = 4 }, .{ .row = 0, .column = 8 } };
    try testing.expectEqualStrings("identifier", node.descendantForPointRange(points[0], points[1]).?.kind());
    try testing.expectEqualStrings("identifier", node.namedDescendantForPointRange(points[0], points[1]).?.kind());

    try testing.expectEqualStrings("body", node.fieldNameForChild(2).?);
    try testing.expectEqualStrings("body", node.fieldNameForNamedChild(2).?);

    const sexp = try node.toSexp(testing.allocator);
    defer testing.allocator.free(sexp);
    try testing.expectStringStartsWith(sexp, "(function_definition type:");

    const new_tree = tree.dupe();
    defer new_tree.destroy();
    const edit: ts.InputEdit = .{
        .start_byte = 0,
        .start_point = .{ .row = 0, .column = 0 },
        .old_end_byte = 13,
        .new_end_byte = 9,
        .old_end_point = .{ .row = 0, .column = 13 },
        .new_end_point = .{ .row = 0, .column = 9 },
    };
    new_tree.edit(edit);
    node = new_tree.rootNode();
    node.edit(edit);

    try testing.expect(node.hasChanges());
    try testing.expect(!node.hasError());
}

test "Query" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    var error_offset: u32 = 0;
    try testing.expectError(error.InvalidNodeType, ts.Query.create(@ptrCast(language), "(foo) @foo", &error_offset));
    try testing.expectEqual(1, error_offset);

    const source =
        \\(identifier) @variable
        \\["{" "}" "(" ")"] @punctuation
        \\((identifier) @main
        \\ (#eq? @main "main"))
    ;
    var query = try ts.Query.create(@ptrCast(language), source, &error_offset);
    defer query.destroy();

    try testing.expectEqual(3, query.patternCount());
    try testing.expectEqual(3, query.captureCount());
    try testing.expectEqual(2, query.stringCount());

    try testing.expectEqual(23, query.startByteForPattern(1));
    try testing.expectEqual(54, query.endByteForPattern(1));

    try testing.expect(query.isPatternRooted(0));
    try testing.expect(!query.isPatternNonLocal(2));
    try testing.expect(!query.isPatternGuaranteedAtStep(9));

    try testing.expectEqualStrings("punctuation", query.captureNameForId(1).?);
    try testing.expectEqual(.one, query.captureQuantifierForId(0, 0).?);
    try testing.expectEqualStrings("main", query.stringValueForId(1).?);

    const steps: [4]ts.Query.PredicateStep = .{
        .{ .type = .string, .value_id = 0 },
        .{ .type = .capture, .value_id = 2 },
        .{ .type = .string, .value_id = 1 },
        .{ .type = .done, .value_id = 0 },
    };
    try testing.expectEqualSlices(ts.Query.PredicateStep, &steps, query.predicatesForPattern(2));
}

test "QueryCursor" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const source =
        \\(identifier) @variable
        \\["{" "}" "(" ")"] @punctuation
        \\((identifier) @main
        \\ (#eq? @main "main"))
    ;
    var error_offset: u32 = 0;
    var query = try ts.Query.create(@ptrCast(language), source, &error_offset);
    defer query.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    const tree = parser.parseStringEncoding("int main() {}", null, .utf8).?;
    defer tree.destroy();

    const cursor = ts.QueryCursor.create();
    defer cursor.destroy();

    cursor.exec(query, tree.rootNode());

    try testing.expect(!cursor.didExceedMatchLimit());
    try testing.expectEqual(0xFFFFFFFF, cursor.getMatchLimit());

    var match = cursor.nextMatch().?;
    try testing.expectEqual(0, match.id);
    try testing.expectEqual(0, match.pattern_index);
    try testing.expectEqual(1, match.captures.len);
    try testing.expectEqual(0, match.captures[0].index);
    try testing.expectEqualStrings("identifier", match.captures[0].node.kind());

    _ = cursor.nextMatch();

    match = cursor.nextCapture().?[1];
    try testing.expectEqual(2, match.id);
    try testing.expectEqual(1, match.pattern_index);
    try testing.expectEqual(1, match.captures.len);
    try testing.expectEqual(1, match.captures[0].index);
    try testing.expectEqualStrings("(", match.captures[0].node.kind());
}

test "Wasm" {
    if (comptime !build.enable_wasm) return error.SkipZigTest;

    const engine = try ts.WasmEngine.init(null);
    defer engine.deinit();

    var error_message: []u8 = undefined;
    const store = ts.WasmStore.create(testing.allocator, engine, &error_message) catch |err| {
        std.log.err("{s}", .{error_message});
        testing.allocator.free(error_message);
        return err;
    };
    defer store.destroy();

    const wasm = @embedFile("tree-sitter-c.wasm");
    const language = store.loadLanguage(testing.allocator, "c", wasm, &error_message) catch |err| {
        std.log.err("{s}", .{error_message});
        testing.allocator.free(error_message);
        return err;
    };
    defer language.destroy();

    try testing.expect(language.isWasm());
    try testing.expectEqual(1, store.languageCount());

    const parser = ts.Parser.create();
    defer parser.destroy();

    try testing.expectError(error.IncompatibleLanguage, parser.setLanguage(language));
    parser.setWasmStore(store);
    defer _ = parser.takeWasmStore();
    try parser.setLanguage(language);

    const tree = parser.parseString("int main() {}", null).?;
    defer tree.destroy();

    try testing.expectEqualStrings("translation_unit", tree.rootNode().kind());

    try testing.expectError(error.ParseError, store.loadLanguage(testing.allocator, "c", "", &error_message));
    try testing.expectEqualStrings("failed to parse dylink section of Wasm module", error_message);
    testing.allocator.free(error_message);
}

test "Node.children" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    const tree = parser.parseString("int main() { return 0; }", null).?;
    defer tree.destroy();

    const root = tree.rootNode();
    var cursor = root.walk();
    defer cursor.destroy();

    const func = root.child(0).?; // function_definition

    // children(): all direct children, returned as an owned slice
    const children = try func.children(&cursor, testing.allocator);
    defer testing.allocator.free(children);
    try testing.expectEqual(3, children.len);
    try testing.expectEqualStrings("primitive_type", children[0].kind());
    try testing.expectEqualStrings("function_declarator", children[1].kind());
    try testing.expectEqualStrings("compound_statement", children[2].kind());

    // namedChildren(): anonymous tokens (the braces) are filtered out
    const body = func.childByFieldName("body").?; // compound_statement
    const named = try body.namedChildren(&cursor, testing.allocator);
    defer testing.allocator.free(named);
    try testing.expectEqual(1, named.len);
    try testing.expectEqualStrings("return_statement", named[0].kind());

    // childrenByFieldName() / childrenByFieldId()
    const by_name = try func.childrenByFieldName("type", &cursor, testing.allocator);
    defer testing.allocator.free(by_name);
    try testing.expectEqual(1, by_name.len);
    try testing.expectEqualStrings("primitive_type", by_name[0].kind());

    const by_id = try func.childrenByFieldId(
        language.fieldIdForName("body"),
        &cursor,
        testing.allocator,
    );
    defer testing.allocator.free(by_id);
    try testing.expectEqual(1, by_id.len);
    try testing.expectEqualStrings("compound_statement", by_id[0].kind());

    // empty cases still return a valid, freeable slice
    const leaf = try children[0].children(&cursor, testing.allocator); // primitive_type is a leaf
    defer testing.allocator.free(leaf);
    try testing.expectEqual(0, leaf.len);

    const no_field = try func.childrenByFieldId(0, &cursor, testing.allocator);
    defer testing.allocator.free(no_field);
    try testing.expectEqual(0, no_field.len);
}

test "Language.supertypes" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    for (language.supertypes()) |supertype| {
        try testing.expect(language.nodeKindForId(supertype) != null);
        const subtypes = language.subtypesForSupertype(supertype);
        try testing.expect(subtypes.len > 0);
        for (subtypes) |sub| try testing.expect(language.nodeKindForId(sub) != null);
    }

    try testing.expectEqual(0, language.subtypesForSupertype(0).len);
}

test "QueryCursor limits and ranges" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    var error_offset: u32 = 0;
    const query = try ts.Query.create(
        @ptrCast(language),
        "(identifier) @id",
        &error_offset,
    );
    defer query.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    const tree = parser.parseString("int main() { return x; }", null).?;
    defer tree.destroy();

    const cursor = ts.QueryCursor.create();
    defer cursor.destroy();

    cursor.setMatchLimit(16);
    try testing.expectEqual(16, cursor.getMatchLimit());

    try cursor.setByteRange(0, 1000);
    try testing.expectError(error.InvalidRange, cursor.setByteRange(10, 5));

    try cursor.setPointRange(
        .{ .row = 0, .column = 0 },
        .{ .row = 100, .column = 0 },
    );

    cursor.setMaxStartDepth(0xFFFFFFFF);

    cursor.exec(query, tree.rootNode());
    var count: usize = 0;
    while (cursor.nextMatch()) |_| count += 1;
    try testing.expect(count >= 1);
}

test "Parser.parse with Input callback" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    // A read callback that serves the whole source in one chunk.
    const Reader = struct {
        fn read(payload: ?*anyopaque, byte_index: u32, _: ts.Point, bytes_read: *u32) callconv(.c) [*c]const u8 {
            const src: *const []const u8 = @ptrCast(@alignCast(payload.?));
            if (byte_index >= src.len) {
                bytes_read.* = 0;
                return "";
            }
            bytes_read.* = @intCast(src.len - byte_index);
            return src.ptr + byte_index;
        }
    };

    var source: []const u8 = "int main() {}";
    const tree = parser.parse(.{
        .payload = @ptrCast(&source),
        .read = &Reader.read,
        .encoding = .utf8,
    }, null).?;
    defer tree.destroy();

    try testing.expectEqualStrings("translation_unit", tree.rootNode().kind());
    try testing.expectEqual(13, tree.rootNode().endByte());
}

test "Parser.setLogger" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    var calls: usize = 0;
    const L = struct {
        fn log(payload: ?*anyopaque, _: ts.Logger.LogType, _: [*:0]const u8) callconv(.c) void {
            const counter: *usize = @ptrCast(@alignCast(payload.?));
            counter.* += 1;
        }
    };
    parser.setLogger(.{ .payload = @ptrCast(&calls), .log = &L.log });

    const tree = parser.parseString("int main() {}", null).?;
    defer tree.destroy();

    try testing.expect(calls > 0);

    const logger = parser.getLogger();
    try testing.expect(logger.log != null);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&calls)), logger.payload);
}

test "Parser.parseWithOptions progress callback" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    // A large input so the progress callback is invoked mid-parse.
    const source: []const u8 = "int a;\n" ** 5000;
    const Ctx = struct {
        src: []const u8,
        fn read(payload: ?*anyopaque, byte_index: u32, _: ts.Point, bytes_read: *u32) callconv(.c) [*c]const u8 {
            const ctx: *@This() = @ptrCast(@alignCast(payload.?));
            if (byte_index >= ctx.src.len) {
                bytes_read.* = 0;
                return "";
            }
            bytes_read.* = @intCast(ctx.src.len - byte_index);
            return ctx.src.ptr + byte_index;
        }
        fn cancel(_: ts.Parser.State) callconv(.c) bool {
            return true;
        }
        fn keep(_: ts.Parser.State) callconv(.c) bool {
            return false;
        }
    };
    var ctx = Ctx{ .src = source };
    const input: ts.Input = .{ .payload = @ptrCast(&ctx), .read = &Ctx.read, .encoding = .utf8 };

    // returning true from the progress callback cancels the parse
    try testing.expect(parser.parseWithOptions(input, null, .{ .progress_callback = &Ctx.cancel }) == null);

    // returning false lets it finish
    parser.reset();
    const tree = parser.parseWithOptions(input, null, .{ .progress_callback = &Ctx.keep }).?;
    defer tree.destroy();
    try testing.expectEqualStrings("translation_unit", tree.rootNode().kind());
}

test "format" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();

    const lang_str = try std.fmt.allocPrint(testing.allocator, "{f}", .{language});
    defer testing.allocator.free(lang_str);
    try testing.expectStringStartsWith(lang_str, "Language(id=0x");
    try testing.expect(std.mem.indexOf(u8, lang_str, "version=15") != null);
    try testing.expect(std.mem.indexOf(u8, lang_str, "name=") != null);

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    const parser_str = try std.fmt.allocPrint(testing.allocator, "{f}", .{parser});
    defer testing.allocator.free(parser_str);
    try testing.expectStringStartsWith(parser_str, "Parser(language=Language(id=0x");
}

test "Tree.printDotGraph" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();
    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));
    const tree = parser.parseString("int main() {}", null).?;
    defer tree.destroy();

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const file = try tmp.dir.createFile(testing.io, "tree.dot", .{ .read = true });
    defer file.close(testing.io);

    tree.printDotGraph(file);
    try testing.expect((try file.stat(testing.io)).size > 0);
}

test "Parser.printDotGraphs" {
    const language = Language.fromRaw(c.language());
    defer language.destroy();
    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(@ptrCast(language));

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const file = try tmp.dir.createFile(testing.io, "graphs.dot", .{ .read = true });
    defer file.close(testing.io);

    parser.printDotGraphs(file);
    const tree = parser.parseString("int main() {}", null).?;
    defer tree.destroy();
    parser.printDotGraphs(null);

    try testing.expect((try file.stat(testing.io)).size > 0);
}

test "refAllDecls" {
    inline for (.{
        ts.Language,    ts.LookaheadIterator, ts.Node,
        ts.Tree,        ts.TreeCursor,        ts.Query,
        ts.QueryCursor,
    }) |T| testing.refAllDecls(T);

    inline for (comptime std.meta.declarations(ts.Parser)) |decl| {
        if (comptime std.mem.eql(u8, decl.name, "setWasmStore") or
            std.mem.eql(u8, decl.name, "takeWasmStore")) continue;
        _ = &@field(ts.Parser, decl.name);
    }

    if (comptime build.enable_wasm) {
        inline for (.{ ts.WasmEngine, ts.WasmStore }) |T| testing.refAllDecls(T);
    }
}
