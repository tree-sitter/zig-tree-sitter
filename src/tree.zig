const std = @import("std");

const Language = @import("language.zig").Language;
const Node = @import("node.zig").Node;
const Point = @import("point.zig").Point;
const Range = @import("point.zig").Range;
const TreeCursor = @import("tree_cursor.zig").TreeCursor;

/// An edit to a text document.
pub const InputEdit = extern struct {
    start_byte: u32,
    old_end_byte: u32,
    new_end_byte: u32,
    start_point: Point,
    old_end_point: Point,
    new_end_point: Point,
};

/// A tree that represents the syntactic structure of a source code file.
pub const Tree = opaque {
    /// Destroy the syntax tree, freeing all of the memory that it used.
    pub fn destroy(self: *Tree) void {
        ts_tree_delete(self);
    }

    /// Create a shallow copy of the syntax tree.
    ///
    /// You need to copy a syntax tree in order to use it mutably on more than
    /// one thread at a time, as syntax trees are not thread safe.
    pub fn dupe(self: *const Tree) *Tree {
        return ts_tree_copy(self);
    }

    /// Get the root node of the syntax tree.
    pub fn rootNode(self: *const Tree) Node {
        return ts_tree_root_node(self);
    }

    /// Get the root node of the syntax tree, but with
    /// its position shifted forward by the given offset.
    pub fn rootNodeWithOffset(self: *const Tree, offset_bytes: u32, offset_extent: Point) Node {
        return ts_tree_root_node_with_offset(self, offset_bytes, offset_extent);
    }

    /// Get the language that was used to parse the syntax tree.
    pub fn getLanguage(self: *const Tree) *const Language {
        return ts_tree_language(self);
    }

    /// Edit the syntax tree to keep it in sync with source code that has been
    /// edited.
    ///
    /// You must describe the edit both in terms of byte offsets and in terms of
    /// row/column coordinates.
    pub fn edit(self: *Tree, input_edit: InputEdit) void {
        ts_tree_edit(self, &input_edit);
    }

    /// Create a new `TreeCursor` starting from the root of the tree.
    pub fn walk(self: *const Tree) TreeCursor {
        return self.rootNode().walk();
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
    /// The caller is responsible for freeing them using `Tree.freeRanges()`.
    pub fn getChangedRanges(self: *const Tree, new_tree: *const Tree) []const Range {
        var length: u32 = 0;
        const ranges = ts_tree_get_changed_ranges(self, new_tree, &length);
        return if (length > 0) ranges[0..length] else &.{};
    }

    /// Get the included ranges of the syntax tree.
    ///
    /// The caller is responsible for freeing them using `Tree.freeRanges()`.
    pub fn getIncludedRanges(self: *const Tree) []const Range {
        var length: u32 = 0;
        const ranges = ts_tree_included_ranges(self, &length);
        return if (length > 0) ranges[0..length] else &.{};
    }

    /// Free the ranges allocated with `Tree.getIncludedRanges()` or `Tree.getChangedRanges()`.
    pub fn freeRanges(ranges: []const Range) void {
        ts_current_free(@ptrCast(@constCast(ranges)));
    }

    /// Print a graph of the tree to the given file.
    ///
    /// The graph is formatted in the DOT language. You may want to pipe this
    /// graph directly to a `dot(1)` process in order to generate SVG
    /// output.
    pub fn printDotGraph(self: *const Tree, file: std.fs.File) void {
        ts_tree_print_dot_graph(self, file.handle);
    }
};

extern var ts_current_free: *const fn ([*]u8) callconv(.c) void;
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
