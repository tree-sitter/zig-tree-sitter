const std = @import("std");
const Language = @import("language.zig").Language;

/// A stateful object that is used to look up valid symbols in a specific parse state.
///
/// Repeatedly using `next()` and `currentSymbol()` will generate valid symbols in the given parse state.
///
/// Lookahead iterators can be useful to generate suggestions and improve syntax error diagnostics.
/// To get symbols valid in an `ERROR` node, use the lookahead iterator on its first leaf node state.
/// For `MISSING` nodes, a lookahead iterator created on the previous non-extra leaf node may be appropriate.
pub const LookaheadIterator = opaque {
    /// Create a new lookahead iterator for the given language and parse state.
    ///
    /// Newly created lookahead iterators will contain the `"ERROR"` symbol (`0xFFFF`).
    ///
    /// This returns `null` if the state is invalid for the language.
    pub inline fn create(lang: *const Language, state: u16) ?*LookaheadIterator {
        return ts_lookahead_iterator_new(lang, state);
    }

    /// Delete the lookahead iterator freeing all the memory used.
    pub inline fn destroy(self: *LookaheadIterator) void {
        ts_lookahead_iterator_delete(self);
    }

    /// Get the current language of the lookahead iterator.
    pub inline fn language(self: *const LookaheadIterator) *const Language {
        return ts_lookahead_iterator_language(self);
    }

    /// Get the current symbol id of the lookahead iterator.
    pub inline fn currentSymbol(self: *const LookaheadIterator) u16 {
        return ts_lookahead_iterator_current_symbol(self);
    }

    /// Get the current symbol name of the lookahead iterator.
    pub fn currentSymbolName(self: *const LookaheadIterator) []const u8 {
        return std.mem.span(ts_lookahead_iterator_current_symbol_name(self));
    }

    /// Advance the lookahead iterator to the next symbol.
    ///
    /// This returns `true` if there is a new symbol and `false` otherwise.
    pub inline fn next(self: *LookaheadIterator) bool {
        return ts_lookahead_iterator_next(self);
    }

    /// Reset the lookahead iterator to another language and state.
    pub inline fn reset(self: *LookaheadIterator, lang: *const Language, state: u16) bool {
        return ts_lookahead_iterator_reset(self, lang, state);
    }

    /// Reset the lookahead iterator to another state.
    pub inline fn resetState(self: *LookaheadIterator, state: u16) bool {
        return ts_lookahead_iterator_reset_state(self, state);
    }
};

extern fn ts_lookahead_iterator_current_symbol(self: *const LookaheadIterator) u16;
extern fn ts_lookahead_iterator_current_symbol_name(self: *const LookaheadIterator) [*:0]const u8;
extern fn ts_lookahead_iterator_delete(self: *LookaheadIterator) void;
extern fn ts_lookahead_iterator_language(self: ?*const LookaheadIterator) *const Language;
extern fn ts_lookahead_iterator_new(self: *const Language, state: u16) ?*LookaheadIterator;
extern fn ts_lookahead_iterator_next(self: *LookaheadIterator) bool;
extern fn ts_lookahead_iterator_reset(self: *LookaheadIterator, language: *const Language, state: u16) bool;
extern fn ts_lookahead_iterator_reset_state(self: *LookaheadIterator, state: u16) bool;
