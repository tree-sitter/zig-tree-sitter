const std = @import("std");

/// A position in a text document in terms of rows and columns.
pub const Point = extern struct {
    /// The zero-based row of the document.
    row: u32,
    /// The zero-based column of the document.
    column: u32,

    /// Compare two points.
    pub fn cmp(self: *const Point, other: Point) std.math.Order {
        const row_diff = self.row - other.row;
        if (row_diff > 0) return .gt;
        if (row_diff < 0) return .lt;

        const col_diff = self.column - other.column;
        if (col_diff == 0) return .eq;
        return if (col_diff > 0) .gt else .lt;
    }
};

/// A range of positions in a text document,
/// both in terms of bytes and of row-column points.
pub const Range = extern struct {
    start_point: Point = .{ .row = 0, .column = 0 },
    end_point: Point = .{ .row = 0xFFFFFFFF, .column = 0xFFFFFFFF },
    start_byte: u32 = 0,
    end_byte: u32 = 0xFFFFFFFF,
};
