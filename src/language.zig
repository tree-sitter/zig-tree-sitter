const std = @import("std");

/// The type of a grammar symbol.
const SymbolType = enum(c_uint) {
    Regular,
    Anonymous,
    Supertype,
    Auxiliary,
};

const LanguageFn = *const fn () callconv(.C) *const Language;

/// An opaque object that defines how to parse a particular language.
pub const Language = opaque {
    /// Load the given language from a library at compile-time.
    pub fn load(comptime language_name: [:0]const u8) *const Language {
        const symbol_name = std.fmt.comptimePrint("tree_sitter_{s}", .{ language_name });
        return @extern(LanguageFn, .{ .name = symbol_name })();
    }

    /// Load the given language from a library at runtime.
    ///
    /// This returns an error if it failed to load the library or find the symbol.
    pub fn dynLoad(library_path: []const u8, symbol_name: [:0]const u8) error{LibError, SymError}!*const Language {
        var library = std.DynLib.open(library_path) catch return error.LibError;
        defer library.close();
        const function = library.lookup(LanguageFn, symbol_name) orelse return error.SymError;
        return function();
    }

    /// Free any dynamically-allocated resources for this language, if this is the last reference.
    pub inline fn destroy(self: *const Language) void {
        ts_language_delete(self);
    }

    /// Get another reference to the given language.
    pub inline fn dupe(self: *const Language) *const Language {
        return ts_language_copy(self);
    }

    /// Get the ABI version number for this language.
    pub inline fn version(self: *const Language) u32 {
        return ts_language_version(self);
    }

    /// Get the number of distinct node types in this language.
    pub inline fn symbolCount(self: *const Language) u32 {
        return ts_language_symbol_count(self);
    }

    /// Get the number of distinct field names in this language.
    pub inline fn fieldCount(self: *const Language) u32 {
        return ts_language_field_count(self);
    }

    /// Get the number of valid states in this language.
    pub inline fn stateCount(self: *const Language) u32 {
        return ts_language_state_count(self);
    }

    /// Get the numerical id for the given field name string.
    pub inline fn fieldIdForName(self: *const Language, name: []const u8) u32 {
        return ts_language_field_id_for_name(self, name.ptr, @intCast(name.len));
    }

    /// Get the field name string for the given numerical id.
    pub fn fieldNameForId(self: *const Language, id: u16) ?[]const u8 {
        return if (ts_language_field_name_for_id(self, id)) |name| std.mem.span(name) else null;
    }

    /// Get the numerical id for the given node type string.
    pub inline fn symbolForName(self: *const Language, string: []const u8, is_named: bool) u16 {
        return ts_language_symbol_for_name(self, string.ptr, @intCast(string.len), is_named);
    }

    /// Get a node type string for the given numerical id.
    pub fn symbolName(self: *const Language, symbol: u16) ?[]const u8 {
        return if (ts_language_symbol_name(self, symbol)) |name| std.mem.span(name) else null;
    }

    /// Check if the node for the given numerical ID is named.
    pub inline fn isNamed(self: *const Language, symbol: u16) bool {
        return ts_language_symbol_type(self, symbol) == SymbolType.Regular;
    }

    /// Check if the node for the given numerical ID is visible.
    pub inline fn isVisible(self: *const Language, symbol: u16) bool {
        const symbol_type = ts_language_symbol_type(self, symbol);
        return @intFromEnum(symbol_type) <= @intFromEnum(SymbolType.Anonymous);
    }

    /// Check if the node for the given numerical ID is a supertype.
    pub inline fn isSupertype(self: *const Language, symbol: u16) bool {
        return ts_language_symbol_type(self, symbol) == SymbolType.Supertype;
    }

    /// Get the next parse state.
    ///
    /// Combine this with a `LookaheadIterator` to generate
    /// completion suggestions or valid symbols in error nodes.
    ///
    /// **Example:**
    /// ```zig
    /// language.nextState(node.parseState(), node.grammarSymbol());
    /// ```
    pub inline fn nextState(self: *const Language, state: u16, symbol: u16) u16 {
        return ts_language_next_state(self, state, symbol);
    }
};

extern fn ts_language_copy(self: *const Language) *const Language;
extern fn ts_language_delete(self: *const Language) void;
extern fn ts_language_field_count(self: *const Language) u32;
extern fn ts_language_field_id_for_name(self: *const Language, name: [*]const u8, name_length: u32) u16;
extern fn ts_language_field_name_for_id(self: *const Language, id: u16) ?[*:0]const u8;
extern fn ts_language_next_state(self: *const Language, state: u16, symbol: u16) u16;
extern fn ts_language_state_count(self: *const Language) u32;
extern fn ts_language_symbol_count(self: *const Language) u32;
extern fn ts_language_symbol_for_name(self: *const Language, string: [*]const u8, length: u32, is_named: bool) u16;
extern fn ts_language_symbol_name(self: *const Language, symbol: u16) ?[*:0]const u8;
extern fn ts_language_symbol_type(self: *const Language, symbol: u16) SymbolType;
extern fn ts_language_version(self: *const Language) u32;
