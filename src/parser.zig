const std = @import("std");

const Input = @import("types.zig").Input;
const InputEdit = @import("types.zig").InputEdit;
const InputEncoding = @import("types.zig").InputEncoding;
const Language = @import("language.zig").Language;
const Logger = @import("types.zig").Logger;
const LogType = @import("types.zig").LogType;
const Node = @import("node.zig").Node;
const Point = @import("types.zig").Point;
const Range = @import("types.zig").Range;
const Tree = @import("tree.zig").Tree;

/// A stateful object that is used to produce
/// a syntax tree based on some source code.
pub const Parser = opaque {
    /// Create a new parser.
    pub inline fn create() *Parser {
        return ts_parser_new();
    }

    /// Delete the parser, freeing all of the memory that it used.
    pub inline fn destroy(self: *Parser) void {
        ts_parser_delete(self);
    }

    /// Get the parser's current language.
    pub inline fn getLanguage(self: *const Parser) ?*const Language {
        return ts_parser_language(self);
    }

    /// Set the language that the parser should use for parsing.
    ///
    /// Returns an error if the language has an incompatible version.
    pub fn setLanguage(self: *Parser, language: ?*const Language) error{IncompatibleVersion}!void {
        if (!ts_parser_set_language(self, language)) {
            return error.IncompatibleVersion;
        }
    }

    /// Get the parser's current logger.
    pub inline fn getLogger(self: *const Parser) Logger {
        return ts_parser_logger(self);
    }

    /// Set the logger that will be used during parsing.
    ///
    /// **Example:**
    /// ```zig
    /// fn scopedLogger(_: ?*anyopaque, log_type: LogType, buffer: [*:0]const u8) callconv(.C) void {
    ///     const scope = switch (log_type) {
    ///         .Parse => std.log.scoped(.PARSE),
    ///         .Lex => std.log.scoped(.LEX),
    ///     };
    ///     scope.debug("{s}", .{ std.mem.span(buffer) });
    /// }
    ///
    /// parser.setLogger(.{ .log = &scopedLogger });
    /// ```
    pub inline fn setLogger(self: *Parser, logger: Logger) void {
        return ts_parser_set_logger(self, logger);
    }

    /// Get the maximum duration in microseconds that parsing
    /// should be allowed to take before halting.
    ///
    /// **Deprecated.** Use `parseInput()` with options instead.
    pub inline fn getTimeoutMicros(self: *const Parser) u64 {
        return ts_parser_timeout_micros(self);
    }

    /// Set the maximum duration in microseconds that parsing
    /// should be allowed to take before halting.
    ///
    /// **Deprecated.** Use `parseInput()` with options instead.
    pub inline fn setTimeoutMicros(self: *Parser, timeout: u64) void {
        return ts_parser_set_timeout_micros(self, timeout);
    }

    /// Get the parser's current cancellation flag pointer.
    ///
    /// **Deprecated.** Use `parseInput()` with options instead.
    pub inline fn getCancellationFlag(self: *const Parser) ?*const usize {
        return ts_parser_cancellation_flag(self);
    }

    /// Set the parser's cancellation flag pointer.
    ///
    /// If a non-null pointer is assigned, then the parser will
    /// periodically read from this pointer during parsing.
    /// If it reads a non-zero value, it will halt early.
    ///
    /// **Deprecated.** Use `parseInput()` with options instead.
    pub inline fn setCancellationFlag(self: *const Parser, flag: ?*const usize) void {
        return ts_parser_set_cancellation_flag(self, flag);
    }

    /// Get the ranges of text that the parser will include when parsing.
    pub fn getIncludedRanges(self: *const Parser) []const Range {
        var count: u32 = 0;
        const ranges = ts_parser_included_ranges(self, &count);
        return ranges[0..count];
    }

    /// Set the ranges of text that the parser should include when parsing.
    ///
    /// By default, the parser will always include entire documents.
    /// This method allows you to parse only a *portion* of a document
    /// but still return a syntax tree whose ranges match up with the
    /// document as a whole. You can also pass multiple disjoint ranges.
    ///
    /// If `ranges` is `null`, the entire document will be parsed.
    /// Otherwise, the given ranges must be ordered from earliest
    /// to latest in the document, and they must not overlap.
    pub fn setIncludedRanges(self: *Parser, ranges: ?[]const Range) error{RangeOverlap}!void {
        if (ranges) |r| {
            if (!ts_parser_set_included_ranges(self, r.ptr, @intCast(r.len))) {
                return error.RangeOverlap;
            }
        } else {
            _ = ts_parser_set_included_ranges(self, null, 0);
        }
    }

    /// Use the parser to parse some source code and create a syntax tree.
    ///
    /// If you are parsing this document for the first time, pass `null` for the
    /// `old_tree` parameter. Otherwise, if you have already parsed an earlier
    /// version of this document and the document has since been edited, pass
    /// the previous tree so that the unchanged parts of it can be reused.
    /// This will save time and memory. For this to work correctly, you must
    /// have already edited the old syntax tree using the `Tree.edit()`
    /// method in a way that exactly matches the source code changes.
    ///
    /// This method returns a syntax tree on success or an appropriate error
    /// if the parser does not have a language assigned, parsing was cancelled,
    /// or a custom encoding was specified without a `decode` function.
    ///
    /// If parsing was cancelled, you can resume from where the parser stopped
    /// by calling the method again with the same arguments. Or you can
    /// start parsing from scratch by first calling the `reset()` method.
    pub fn parseInput(
        self: *Parser,
        input: Input,
        old_tree: ?*const Tree,
        options: ?Options,
    ) error{ NoLanguage, Cancellation, InvalidEncoding }!*Tree {
        if (self.getLanguage() == null) return error.NoLanguage;
        if (input.encoding == .Custom and input.decode == null) return error.InvalidEncoding;
        const new_tree = if (options) |o|
            ts_parser_parse_with_options(self, old_tree, input, o)
        else
            ts_parser_parse(self, old_tree, input);
        return new_tree orelse error.Cancellation;
    }

    /// Use the parser to parse some source code stored in one contiguous buffer,
    /// optionally with a given encoding (defaults to `InputEncoding.UTF_8`).
    ///
    /// See the `parseInput()` method for more details.
    pub fn parseBuffer(
        self: *Parser,
        buffer: []const u8,
        old_tree: ?*const Tree,
        encoding: ?InputEncoding,
    ) error{ NoLanguage, Cancellation, InvalidEncoding }!*Tree {
        if (self.getLanguage() == null) return error.NoLanguage;
        if (encoding == .Custom) return error.InvalidEncoding;
        return ts_parser_parse_string_encoding(
            self,
            old_tree,
            buffer.ptr,
            @intCast(buffer.len),
            encoding orelse InputEncoding.UTF_8,
        ) orelse error.Cancellation;
    }

    /// Instruct the parser to start the next parse from the beginning.
    ///
    /// If the parser previously failed because of a timeout or a cancellation,
    /// then by default, it will resume where it left off on the next call to a
    /// parsing method. If you don't want to resume, and instead intend to use
    /// this parser to parse some other document, you must call this method first.
    pub inline fn reset(self: *Parser) void {
        ts_parser_reset(self);
    }

    /// Set the file to which the parser should write debugging graphs
    /// during parsing. The graphs are formatted in the DOT language.
    ///
    /// Pass a `null` file to stop printing debugging graphs.
    ///
    /// **Example:**
    /// ```zig
    /// parser.printDotGraphs(std.io.getStdOut());
    /// ```
    pub fn printDotGraphs(self: *Parser, file: ?std.fs.File) void {
        ts_parser_print_dot_graphs(self, if (file) |f| f.handle else -1);
    }

    /// An object that represents the current state of the parser.
    pub const State = extern struct {
        payload: ?*anyopaque = null,
        /// The byte offset in the document that the parser is currently at.
        current_byte_offset: u32,
        /// Indicates whether the parser has encountered an error during parsing.
        has_error: bool,
    };

    /// An object which contains the parsing options.
    pub const Options = extern struct {
        payload: ?*anyopaque = null,
        /// A callback that receives the parse state during parsing.
        progress_callback: *const fn (state: State) callconv(.C) bool,
    };
};

extern fn ts_parser_new() *Parser;
extern fn ts_parser_delete(self: *Parser) void;
extern fn ts_parser_language(self: *const Parser) ?*const Language;
extern fn ts_parser_set_language(self: *Parser, language: ?*const Language) bool;
extern fn ts_parser_set_included_ranges(self: *Parser, ranges: [*c]const Range, count: u32) bool;
extern fn ts_parser_included_ranges(self: *const Parser, count: *u32) [*c]const Range;
extern fn ts_parser_parse(self: *Parser, old_tree: ?*const Tree, input: Input) ?*Tree;
extern fn ts_parser_parse_with_options(
    self: *Parser,
    old_tree: ?*const Tree,
    input: Input,
    options: Parser.Options,
) ?*Tree;
// extern fn ts_parser_parse_string(self: *Parser, old_tree: ?*const Tree, string: [*c]const u8, length: u32) ?*Tree;
extern fn ts_parser_parse_string_encoding(
    self: *Parser,
    old_tree: ?*const Tree,
    string: [*c]const u8,
    length: u32,
    encoding: InputEncoding,
) ?*Tree;
extern fn ts_parser_reset(self: *Parser) void;
extern fn ts_parser_set_timeout_micros(self: *Parser, timeout_micros: u64) void;
extern fn ts_parser_timeout_micros(self: *const Parser) u64;
extern fn ts_parser_set_cancellation_flag(self: *Parser, flag: ?*const usize) void;
extern fn ts_parser_cancellation_flag(self: *const Parser) ?*const usize;
extern fn ts_parser_set_logger(self: *Parser, logger: Logger) void;
extern fn ts_parser_logger(self: *const Parser) Logger;
extern fn ts_parser_print_dot_graphs(self: *Parser, fd: c_int) void;
