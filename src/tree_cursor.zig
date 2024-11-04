const std = @import("std");

const Point = @import("types.zig").Point;
const Node = @import("node.zig").Node;
const Tree = @import("tree.zig").Tree;

/// A stateful object for walking a syntax tree efficiently.
pub const TreeCursor = extern struct {
    /// The syntax tree this cursor belongs to.
    tree: *const Tree,

    /// **Internal.** The id of the tree cursor.
    id: *const anyopaque,

    /// **Internal.** The context of the tree cursor.
    context: [3]u32,

    /// Create a new tree cursor starting from the given node.
    pub inline fn create(node: Node) TreeCursor {
        return ts_tree_cursor_new(node);
    }

    /// Delete the tree cursor, freeing all of the memory that it used.
    pub inline fn destroy(self: *TreeCursor) void {
        ts_tree_cursor_delete(self);
    }

    /// Create a shallow copy of the tree cursor.
    pub inline fn dupe(self: *const TreeCursor) TreeCursor {
        return ts_tree_cursor_copy(self);
    }

    /// Get the current node of the tree cursor.
    pub inline fn currentNode(self: *const TreeCursor) Node {
        return ts_tree_cursor_current_node(self);
    }

    /// Get the field name of the tree cursor's current node.
    ///
    /// This returns `null` if the current node doesn't have a field.
    pub fn currentFieldName(self: *const TreeCursor) ?[]const u8 {
        return if (ts_tree_cursor_current_field_name(self)) |name| std.mem.span(name) else null;
    }

    /// Get the field id of the tree cursor's current node.
    ///
    /// This returns `0` if the current node doesn't have a field.
    pub inline fn currentFieldId(self: *const TreeCursor) u16 {
        return ts_tree_cursor_current_field_id(self);
    }

    /// Get the depth of the cursor's current node relative to
    /// the original node that the cursor was constructed with.
    pub inline fn currentDepth(self: *const TreeCursor) u32 {
        return ts_tree_cursor_current_depth(self);
    }

    /// Get the index of the cursor's current node out of all of the
    /// descendants of the original node that the cursor was constructed with.
    pub inline fn currentDescendantIndex(self: *const TreeCursor) u32 {
        return ts_tree_cursor_current_descendant_index(self);
    }

    /// Move the cursor to the parent of its current node.
    ///
    /// This returns `true` if the cursor successfully moved,
    /// or `false` if there was no parent node.
    pub inline fn gotoParent(self: *TreeCursor) bool {
        return ts_tree_cursor_goto_parent(self);
    }

    /// Move the cursor to the next sibling of its current node.
    ///
    /// This returns `true` if the cursor successfully moved,
    /// or `false` if there was no next sibling node.
    pub inline fn gotoNextSibling(self: *TreeCursor) bool {
        return ts_tree_cursor_goto_next_sibling(self);
    }

    /// Move the cursor to the previous sibling of its current node.
    ///
    /// This returns `true` if the cursor successfully moved,
    /// or `false` if there was no previous sibling node.
    pub inline fn gotoPreviousSibling(self: *TreeCursor) bool {
        return ts_tree_cursor_goto_previous_sibling(self);
    }

    /// Move the cursor to the first child of its current node.
    ///
    /// This returns `true` if the cursor successfully moved,
    /// or `false` if there were no children.
    pub inline fn gotoFirstChild(self: *TreeCursor) bool {
        return ts_tree_cursor_goto_first_child(self);
    }

    /// Move the cursor to the last child of its current node.
    ///
    /// This returns `true` if the cursor successfully moved,
    /// or `false` if there were no children.
    pub inline fn gotoLastChild(self: *TreeCursor) bool {
        return ts_tree_cursor_goto_last_child(self);
    }

    /// Move the cursor to the nth descendant node of the
    /// original node that the cursor was constructed with,
    /// where `0` represents the original node itself.
    pub inline fn gotoDescendant(self: *TreeCursor, index: u32) void {
        return ts_tree_cursor_goto_descendant(self, index);
    }

    /// Move the cursor to the first child of its current
    /// node that extends beyond the given byte offset.
    ///
    /// This returns the index of the child node if one was found, or `null`.
    pub inline fn gotoFirstChildForByte(self: *TreeCursor, byte: u32) ?u32 {
        const index = ts_tree_cursor_goto_first_child_for_byte(self, byte);
        return if (index >= 0) @intCast(index) else null;
    }

    /// Move the cursor to the first child of its current
    /// node that extends beyond the given point.
    ///
    /// This returns the index of the child node if one was found, or `null`.
    pub inline fn gotoFirstChildForPoint(self: *TreeCursor, point: Point) ?u32 {
        const index = ts_tree_cursor_goto_first_child_for_point(self, point);
        return if (index >= 0) @intCast(index) else null;
    }

    /// Re-initialize a tree cursor to start at the node it was constructed with.
    pub inline fn reset(self: *TreeCursor, node: Node) void {
        ts_tree_cursor_reset(self, node);
    }

    /// Re-initialize a tree cursor to the same position as another cursor.
    pub inline fn resetTo(self: *TreeCursor, other: *const TreeCursor) void {
        ts_tree_cursor_reset_to(self, other);
    }
};

extern fn ts_tree_cursor_new(node: Node) TreeCursor;
extern fn ts_tree_cursor_delete(self: *TreeCursor) void;
extern fn ts_tree_cursor_reset(self: *TreeCursor, node: Node) void;
extern fn ts_tree_cursor_reset_to(dst: *TreeCursor, src: *const TreeCursor) void;
extern fn ts_tree_cursor_current_node(self: *const TreeCursor) Node;
extern fn ts_tree_cursor_current_field_name(self: *const TreeCursor) ?[*:0]const u8;
extern fn ts_tree_cursor_current_field_id(self: *const TreeCursor) u16;
extern fn ts_tree_cursor_goto_parent(self: *TreeCursor) bool;
extern fn ts_tree_cursor_goto_next_sibling(self: *TreeCursor) bool;
extern fn ts_tree_cursor_goto_previous_sibling(self: *TreeCursor) bool;
extern fn ts_tree_cursor_goto_first_child(self: *TreeCursor) bool;
extern fn ts_tree_cursor_goto_last_child(self: *TreeCursor) bool;
extern fn ts_tree_cursor_goto_descendant(self: *TreeCursor, goal_descendant_index: u32) void;
extern fn ts_tree_cursor_current_descendant_index(self: *const TreeCursor) u32;
extern fn ts_tree_cursor_current_depth(self: *const TreeCursor) u32;
extern fn ts_tree_cursor_goto_first_child_for_byte(self: *TreeCursor, goal_byte: u32) i64;
extern fn ts_tree_cursor_goto_first_child_for_point(self: *TreeCursor, goal_point: Point) i64;
extern fn ts_tree_cursor_copy(cursor: *const TreeCursor) TreeCursor;
