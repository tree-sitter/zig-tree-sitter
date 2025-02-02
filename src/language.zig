const std = @import("std");

/// The type of a grammar symbol.
const SymbolType = enum(c_uint) {
    Regular,
    Anonymous,
    Supertype,
    Auxiliary,
};

const LanguageMetadata = extern struct {
    major_version: u8,
    minor_version: u8,
    patch_version: u8,
};

const LanguageFn = *const fn () callconv(.C) *const Language;

/// An opaque object that defines how to parse a particular language.
pub const Language = opaque {
    /// Free any dynamically-allocated resources for this language, if this is the last reference.
    pub inline fn destroy(self: *const Language) void {
        ts_language_delete(self);
    }

    /// Get another reference to the given language.
    pub inline fn dupe(self: *const Language) *const Language {
        return ts_language_copy(self);
    }

    /// Get the name of the language, if available.
    pub fn name(self: *const Language) ?[]const u8 {
        return if (ts_language_name(self)) |n| std.mem.span(n) else null;
    }

    /// Get the ABI version number for this language.
    pub inline fn abi_version(self: *const Language) u32 {
        return ts_language_abi_version(self);
    }

    /// Get the semantic version for this language.
    pub fn semantic_version(self: *const Language) ?std.SemanticVersion {
        const data = ts_language_metadata(self) orelse return null;
        return .{
            .major = @intCast(data.major_version),
            .minor = @intCast(data.minor_version),
            .patch = @intCast(data.patch_version),
        };
    }

    /// Get the ABI version number for this language.
    ///
    /// **Deprecated.** Use `abi_version()` instead.
    pub inline fn version(self: *const Language) u32 {
        return ts_language_abi_version(self);
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
    pub inline fn fieldIdForName(self: *const Language, field_name: []const u8) u32 {
        return ts_language_field_id_for_name(self, field_name.ptr, @intCast(field_name.len));
    }

    /// Get the field name string for the given numerical id.
    pub fn fieldNameForId(self: *const Language, field_id: u16) ?[]const u8 {
        return if (ts_language_field_name_for_id(self, field_id)) |n| std.mem.span(n) else null;
    }

    /// Get the numerical id for the given node type string.
    pub inline fn symbolForName(self: *const Language, string: []const u8, is_named: bool) u16 {
        return ts_language_symbol_for_name(self, string.ptr, @intCast(string.len), is_named);
    }

    /// Get a node type string for the given numerical id.
    pub fn symbolName(self: *const Language, symbol: u16) ?[]const u8 {
        return if (ts_language_symbol_name(self, symbol)) |n| std.mem.span(n) else null;
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

    /// Get a list of all subtype symbols for a given supertype symbol.
    pub fn subtypes(self: *const Language, supertype: u16) []const u16 {
        var length: u32 = 0;
        const results = ts_language_subtypes(self, supertype, &length);
        return if (length > 0) results[0..length] else &.{};
    }

    /// Get a list of all supertype symbols for the language.
    pub fn supertypes(self: *const Language) []const u16 {
        var length: u32 = 0;
        const results = ts_language_supertypes(self, &length);
        return if (length > 0) results[0..length] else &.{};
    }
};

extern fn ts_language_abi_version(self: *const Language) u32;
extern fn ts_language_copy(self: *const Language) *const Language;
extern fn ts_language_delete(self: *const Language) void;
extern fn ts_language_field_count(self: *const Language) u32;
extern fn ts_language_field_id_for_name(self: *const Language, name: [*]const u8, name_length: u32) u16;
extern fn ts_language_field_name_for_id(self: *const Language, id: u16) ?[*:0]const u8;
extern fn ts_language_metadata(self: *const Language) ?*const LanguageMetadata;
extern fn ts_language_name(self: *const Language) ?[*:0]const u8;
extern fn ts_language_next_state(self: *const Language, state: u16, symbol: u16) u16;
extern fn ts_language_state_count(self: *const Language) u32;
extern fn ts_language_subtypes(self: *const Language, supertype: u16, length: *u32) [*c]const u16;
extern fn ts_language_supertypes(self: *const Language, length: *u32) [*c]const u16;
extern fn ts_language_symbol_count(self: *const Language) u32;
extern fn ts_language_symbol_for_name(self: *const Language, string: [*]const u8, length: u32, is_named: bool) u16;
extern fn ts_language_symbol_name(self: *const Language, symbol: u16) ?[*:0]const u8;
extern fn ts_language_symbol_type(self: *const Language, symbol: u16) SymbolType;
