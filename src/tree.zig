const std = @import("std");

const InputEdit = @import("types.zig").InputEdit;
const Language = @import("language.zig").Language;
const Node = @import("node.zig").Node;
const Point = @import("types.zig").Point;
const Range = @import("types.zig").Range;

/// A tree that represents the syntactic structure of a source code file.
pub const Tree = opaque {
    /// Delete the syntax tree, freeing all of the memory that it used.
    pub inline fn destroy(self: *Tree) void {
        ts_tree_delete(self);
    }

    /// Create a shallow copy of the syntax tree.
    ///
    /// You need to copy a syntax tree in order to use it on more than
    /// one thread at a time, as syntax trees are not thread safe.
    pub inline fn dupe(self: *const Tree) *Tree {
        return ts_tree_copy(self);
    }

    /// Get the root node of the syntax tree.
    pub inline fn rootNode(self: *const Tree) Node {
        return ts_tree_root_node(self);
    }

    /// Get the root node of the syntax tree, with
    /// its position shifted forward by the given offset.
    pub inline fn rootNodeWithOffset(self: *const Tree, offset_bytes: u32, offset_extent: Point) Node {
        return ts_tree_root_node_with_offset(self, offset_bytes, offset_extent);
    }

    /// Get the language that was used to parse the syntax tree.
    pub inline fn language(self: *const Tree) *const Language {
        return ts_tree_language(self);
    }

    /// Get the included ranges of the syntax tree.
    ///
    /// The caller is responsible for freeing them using `freeRanges`.
    pub fn getIncludedRanges(self: *const Tree) []const Range {
        var length: u32 = 0;
        const ranges = ts_tree_included_ranges(self, &length);
        return if (length > 0) ranges[0..length] else &.{};
    }

    /// Compare an old edited syntax tree to a new syntax
    /// tree representing the same document, returning the
    /// ranges whose syntactic structure has changed.
    ///
    /// For this to work correctly, this tree must have been
    /// edited such that its ranges match up to the new tree.
    ///
    /// The returned ranges indicate areas where the hierarchical
    /// structure of syntax nodes (from root to leaf) has changed
    /// between the old and new trees. Characters outside these
    /// ranges have identical ancestor nodes in both trees.
    ///
    /// The caller is responsible for freeing them using `freeRanges()`.
    pub fn getChangedRanges(self: *const Tree, new_tree: *const Tree) []const Range {
        var length: u32 = 0;
        const ranges = ts_tree_get_changed_ranges(self, new_tree, &length);
        return if (length > 0) ranges[0..length] else &.{};
    }

    /// Free the ranges allocated with `getIncludedRanges()` or `getChangedRanges()`.
    pub fn freeRanges(ranges: []const Range) void {
        std.c.free(@ptrCast(@constCast(ranges)));
    }

    /// Edit the syntax tree to keep it in sync with source code that has been edited.
    pub inline fn edit(self: *Tree, input_edit: InputEdit) void {
        ts_tree_edit(self, &input_edit);
    }

    /// Write a DOT graph describing the syntax tree to the given file.
    ///
    /// The file is closed automatically.
    pub fn printDotGraph(self: *const Tree, file: std.fs.File) void {
        ts_tree_print_dot_graph(self, file.handle);
    }
};

extern fn ts_node_is_null(self: Node) bool;
extern fn ts_tree_copy(self: *const Tree) *Tree;
extern fn ts_tree_delete(self: *Tree) void;
extern fn ts_tree_root_node(self: *const Tree) Node;
extern fn ts_tree_root_node_with_offset(self: *const Tree, offset_bytes: u32, offset_extent: Point) Node;
extern fn ts_tree_language(self: *const Tree) *const Language;
extern fn ts_tree_included_ranges(self: *const Tree, length: *u32) [*c]Range;
extern fn ts_tree_edit(self: *Tree, edit: *const InputEdit) void;
extern fn ts_tree_get_changed_ranges(old_tree: *const Tree, new_tree: *const Tree, length: *u32) [*c]Range;
extern fn ts_tree_print_dot_graph(self: *const Tree, file_descriptor: c_int) void;
