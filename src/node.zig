const std = @import("std");

const InputEdit = @import("types.zig").InputEdit;
const Point = @import("types.zig").Point;
const Range = @import("types.zig").Range;
const Language = @import("language.zig").Language;
const Tree = @import("tree.zig").Tree;

/// A single node within a syntax tree.
pub const Node = extern struct {
    /// **Internal.** The context of the node.
    context: [4]u32,

    /// The ID of the node.
    ///
    /// Within any given syntax tree, no two nodes have the same ID.
    /// However, if a new tree is created based on an older tree,
    /// and a node from the old tree is reused in the process,
    /// then that node will have the same ID in both trees.
    id: *const anyopaque,

    /// The syntax tree this node belongs to.
    tree: *const Tree,

    /// Check if two nodes are identical.
    pub inline fn eql(self: Node, other: Node) bool {
        return ts_node_eq(self, other);
    }

    /// Get the node's language.
    pub inline fn language(self: Node) *const Language {
        return ts_node_language(self);
    }

    /// Get the numerical ID of the node's type.
    pub inline fn symbol(self: Node) u16 {
        return ts_node_symbol(self);
    }

    /// Get the numerical ID of the node's type,
    /// as it appears in the grammar ignoring aliases.
    pub inline fn grammarSymbol(self: Node) u16 {
        return ts_node_grammar_symbol(self);
    }

    /// Get the type of the node.
    pub fn @"type"(self: Node) []const u8 {
        return std.mem.span(ts_node_type(self));
    }

    /// Get the type of the node, as it appears in the grammar ignoring aliases.
    pub fn grammarType(self: Node) []const u8 {
        return std.mem.span(ts_node_grammar_type(self));
    }

    /// Check if the node is *named*.
    ///
    /// Named nodes correspond to named rules in the grammar,
    /// whereas *anonymous* nodes correspond to string literals.
    pub inline fn isNamed(self: Node) bool {
        return ts_node_is_named(self);
    }

    /// Check if the node is *extra*.
    ///
    /// Extra nodes represent things which are not required
    /// by the grammar but can appear anywhere (e.g. whitespace).
    pub inline fn isExtra(self: Node) bool {
        return ts_node_is_extra(self);
    }

    /// Check if the node is a syntax error.
    pub inline fn isError(self: Node) bool {
        return ts_node_is_error(self);
    }

    /// Check if the node is *missing*.
    ///
    /// Missing nodes are inserted by the parser in order
    /// to recover from certain kinds of syntax errors.
    pub inline fn isMissing(self: Node) bool {
        return ts_node_is_missing(self);
    }

    /// Check if the node has been edited.
    pub inline fn hasChanges(self: Node) bool {
        return ts_node_has_changes(self);
    }

    /// Check if the node is a syntax error, or contains any syntax errors.
    pub inline fn hasError(self: Node) bool {
        return ts_node_has_error(self);
    }

    /// Get the parse state of this node.
    pub inline fn parseState(self: Node) u16 {
        return ts_node_parse_state(self);
    }

    /// Get the parse state after this node.
    pub inline fn nextParseState(self: Node) u16 {
        return ts_node_next_parse_state(self);
    }

    /// Get the start byte of the node.
    pub inline fn startByte(self: Node) u32 {
        return ts_node_start_byte(self);
    }

    /// Get the end byte of the node.
    pub inline fn endByte(self: Node) u32 {
        return ts_node_end_byte(self);
    }

    /// The start point of the node.
    pub inline fn startPoint(self: Node) Point {
        return ts_node_start_point(self);
    }

    /// Get the end point of the node.
    pub inline fn endPoint(self: Node) Point {
        return ts_node_end_point(self);
    }

    /// Get the range of the node.
    pub fn range(self: Node) Range {
        return .{
            .start_byte = self.startByte(),
            .end_byte = self.endByte(),
            .start_point = self.startPoint(),
            .end_point = self.startPoint()
        };
    }

    /// Get the number of the node's children.
    pub inline fn childCount(self: Node) u32 {
        return ts_node_child_count(self);
    }

    /// Get the number of the node's *named* children.
    pub inline fn namedChildCount(self: Node) u32 {
        return ts_node_named_child_count(self);
    }

    /// Get the number of the node's descendants,
    /// including the node itself.
    pub inline fn descendantCount(self: Node) u32 {
        return ts_node_descendant_count(self);
    }

    /// Get the node's immediate parent.
    pub inline fn parent(self: Node) ?Node {
        return ts_node_parent(self).orNull();
    }

    /// Get the node's next sibling.
    pub inline fn nextSibling(self: Node) ?Node {
        return ts_node_next_sibling(self).orNull();
    }

    /// Get the node's next *named* sibling.
    pub inline fn nextNamedSibling(self: Node) ?Node {
        return ts_node_next_named_sibling(self).orNull();
    }

    /// Get the node's previous sibling.
    pub inline fn prevSibling(self: Node) ?Node {
        return ts_node_prev_sibling(self).orNull();
    }

    /// Get the node's previous *named* sibling.
    pub inline fn prevNamedSibling(self: Node) ?Node {
        return ts_node_prev_named_sibling(self).orNull();
    }

    /// Get the node's child at the given index.
    pub inline fn child(self: Node, child_index: u32) ?Node {
        return ts_node_child(self, child_index).orNull();
    }

    /// Get the node's *named* child at the given index.
    pub inline fn namedChild(self: Node, child_index: u32) ?Node {
        return ts_node_named_child(self, child_index).orNull();
    }

    /// Get the node's child with the given numerical field id.
    pub inline fn childByFieldId(self: Node, field_id: u16) ?Node {
        return ts_node_child_by_field_id(self, field_id).orNull();
    }

    /// Get the node's child with the given field name.
    pub inline fn childByFieldName(self: Node, name: []const u8) ?Node {
        return ts_node_child_by_field_name(self, name.ptr, @intCast(name.len)).orNull();
    }

    /// **Deprecated.** Use `childWithDescendant` instead.
    ///
    /// Get the node's child containing `descendant`.
    ///
    /// This will not return the descendant if it is a direct child of `self`.
    pub inline fn childContainingDescendant(self: Node, descendant: Node) ?Node {
        return ts_node_child_containing_descendant(self, descendant).orNull();
    }

    /// Get the node that contains `descendant`.
    pub inline fn childWithDescendant(self: Node, descendant: Node) ?Node {
        return ts_node_child_with_descendant(self, descendant).orNull();
    }

    /// Get the smallest node within this node that spans the given byte range.
    pub inline fn descendantForByteRange(self: Node, start: u32, end: u32) ?Node {
        return ts_node_descendant_for_byte_range(self, start, end).orNull();
    }

    /// Get the smallest *named* node within this node that spans the given byte range.
    pub inline fn namedDescendantForByteRange(self: Node, start: u32, end: u32) ?Node {
        return ts_node_named_descendant_for_byte_range(self, start, end).orNull();
    }

    /// Get the smallest node within this node that spans the given point range.
    pub inline fn descendantForPointRange(self: Node, start: Point, end: Point) ?Node {
        return ts_node_descendant_for_point_range(self, start, end).orNull();
    }

    /// Get the smallest *named* node within this node that spans the given point range.
    pub inline fn namedDescendantForPointRange(self: Node, start: Point, end: Point) ?Node {
        return ts_node_named_descendant_for_point_range(self, start, end).orNull();
    }

    /// Get the field name for the node's child at the given index.
    pub fn fieldNameForChild(self: Node, child_index: u32) ?[]const u8 {
        return if (ts_node_field_name_for_child(self, child_index)) |name| std.mem.span(name) else null;
    }

    /// Get the field name for the node's named child at the given index.
    pub fn fieldNameForNamedChild(self: Node, child_index: u32) ?[]const u8 {
        return if (ts_node_field_name_for_named_child(self, child_index)) |name| std.mem.span(name) else null;
    }

    /// Edit the node to keep it in-sync with source code that has been edited.
    ///
    /// This function is only rarely needed. When you edit a syntax tree with the
    /// `Tree.edit()` function, all of the nodes that you retrieve from the tree
    /// afterward will already reflect the edit. You only need to use this when you
    /// have a `Node` instance that you want to keep and continue to use after an edit.
    pub inline fn edit(self: *Node, input_edit: InputEdit) void {
        ts_node_edit(self, &input_edit);
    }

    /// Get an S-expression representing the node.
    ///
    /// The caller is responsible for freeing it using `freeSexp`.
    pub fn toSexp(self: Node) []const u8 {
        return std.mem.span(ts_node_string(self));
    }

    /// Free an S-expression allocated with `toSexp()`.
    pub fn freeSexp(sexp: []const u8) void {
        std.c.free(@ptrCast(@constCast(sexp)));
    }

    /// Format the node as a string.
    ///
    /// Use `{s}` to get an S-expression.
    pub fn format(self: Node, comptime fmt: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (std.mem.eql(u8, fmt, "s")) {
            const sexp = self.toSexp();
            defer freeSexp(sexp);
            return writer.print("{s}", .{ sexp });
        }

        if (fmt.len == 0 or std.mem.eql(u8, fmt, "any")) {
            return writer.print(
                "Node(id=0x{x}, type={s}, start={d}, end={d})", .{
                    @intFromPtr(self.id),
                    self.@"type"(),
                    self.startByte(),
                    self.endByte()
                }
            );
        }

        return std.fmt.invalidFmtError(fmt, self);
    }

    inline fn orNull(self: Node) ?Node {
        return if (!ts_node_is_null(self)) self else null;
    }
};

extern fn ts_node_child(self: Node, child_index: u32) Node;
extern fn ts_node_child_by_field_id(self: Node, field_id: u16) Node;
extern fn ts_node_child_by_field_name(self: Node, name: [*]const u8, name_length: u32) Node;
extern fn ts_node_child_containing_descendant(self: Node, descendant: Node) Node;
extern fn ts_node_child_with_descendant(self: Node, descendant: Node) Node;
extern fn ts_node_child_count(self: Node) u32;
extern fn ts_node_descendant_count(self: Node) u32;
extern fn ts_node_descendant_for_byte_range(self: Node, start: u32, end: u32) Node;
extern fn ts_node_descendant_for_point_range(self: Node, start: Point, end: Point) Node;
extern fn ts_node_edit(self: *Node, edit: *const InputEdit) void;
extern fn ts_node_end_byte(self: Node) u32;
extern fn ts_node_end_point(self: Node) Point;
extern fn ts_node_eq(self: Node, other: Node) bool;
extern fn ts_node_field_name_for_child(self: Node, child_index: u32) ?[*:0]const u8;
extern fn ts_node_field_name_for_named_child(self: Node, named_child_index: u32) ?[*:0]const u8;
extern fn ts_node_first_child_for_byte(self: Node, byte: u32) Node;
extern fn ts_node_first_named_child_for_byte(self: Node, byte: u32) Node;
extern fn ts_node_grammar_symbol(self: Node) u16;
extern fn ts_node_grammar_type(self: Node) [*:0]const u8;
extern fn ts_node_has_changes(self: Node) bool;
extern fn ts_node_has_error(self: Node) bool;
extern fn ts_node_is_error(self: Node) bool;
extern fn ts_node_is_extra(self: Node) bool;
extern fn ts_node_is_missing(self: Node) bool;
extern fn ts_node_is_named(self: Node) bool;
extern fn ts_node_is_null(self: Node) bool;
extern fn ts_node_language(self: Node) *const Language;
extern fn ts_node_named_child(self: Node, child_index: u32) Node;
extern fn ts_node_named_child_count(self: Node) u32;
extern fn ts_node_named_descendant_for_byte_range(self: Node, start: u32, end: u32) Node;
extern fn ts_node_named_descendant_for_point_range(self: Node, start: Point, end: Point) Node;
extern fn ts_node_next_named_sibling(self: Node) Node;
extern fn ts_node_next_parse_state(self: Node) u16;
extern fn ts_node_next_sibling(self: Node) Node;
extern fn ts_node_parent(self: Node) Node;
extern fn ts_node_parse_state(self: Node) u16;
extern fn ts_node_prev_named_sibling(self: Node) Node;
extern fn ts_node_prev_sibling(self: Node) Node;
extern fn ts_node_start_byte(self: Node) u32;
extern fn ts_node_start_point(self: Node) Point;
extern fn ts_node_string(self: Node) [*c]u8;
extern fn ts_node_symbol(self: Node) u16;
extern fn ts_node_type(self: Node) [*:0]const u8;
