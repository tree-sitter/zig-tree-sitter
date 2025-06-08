const std = @import("std");
const log = std.log;

const build_options = @import("build_options");

const ts = @import("root.zig");
const Language = ts.Language;

const WasmError = extern struct {
    kind: Kind,
    message: [*c]u8,

    const Kind = enum(c_int) {
        none,
        parse,
        compile,
        instantiate,
        allocate,
    };
};

pub const WasmEngine = opaque {
    pub fn new() !*WasmEngine {
        if (!build_options.wasm_enabled) @compileError("Set enable-wasm=true in build options to use WasmEngine");

        if (wasm_engine_new()) |engine| {
            return engine;
        } else {
            return error.FailedToCreateWasmEngine;
        }
    }

    pub fn delete(engine: *WasmEngine) void {
        wasm_engine_delete(engine);
    }
};

pub const WasmStore = opaque {
    pub fn new(engine: *WasmEngine) !*WasmStore {
        if (!build_options.wasm_enabled) @compileError("Set enable-wasm=true in build options to use WasmStore");

        var err_msg_buf: [256]u8 = undefined;
        var wasm_error = WasmError{ .kind = .none, .message = &err_msg_buf };

        if (ts_wasm_store_new(engine, &wasm_error)) |store| {
            return store;
        } else {
            log.err("{s} error: {s}", .{ @tagName(wasm_error.kind), wasm_error.message });
            return error.FailedToCreateWasmStore;
        }
    }

    pub fn delete(store: *WasmStore) void {
        ts_wasm_store_delete(store);
    }

    ///Create a language from a buffer of Wasm. The resulting language behaves
    ///like any other Tree-sitter language, except that in order to use it with
    ///a parser, that parser must have a Wasm store. Note that the language
    ///can be used with any Wasm store, it doesn't need to be the same store that
    ///was used to originally load it.
    pub fn loadLanguage(store: *WasmStore, name: [*:0]const u8, wasm: []const u8) !*Language {
        var err_msg_buf: [256]u8 = undefined;
        var wasm_error = WasmError{ .kind = .none, .message = &err_msg_buf };

        if (wasm.len >= std.math.maxInt(u32)) return error.WasmSliceTooLong;

        if (ts_wasm_store_load_language(store, name, wasm.ptr, @intCast(wasm.len), &wasm_error)) |lang| {
            std.debug.assert(wasm_error.kind == .none);
            return lang;
        } else {
            log.err("{s} error: {s}", .{ @tagName(wasm_error.kind), wasm_error.message });
            return error.FailedToLoadLanguage;
        }
    }

    /// Get the number of languages instantiated in the given wasm store.
    pub fn languageCount(store: *WasmStore) usize {
        return ts_wasm_store_language_count(store);
    }
};

extern fn wasm_engine_new() ?*WasmEngine;
extern fn wasm_engine_delete(engine: *const WasmEngine) void;
extern fn ts_wasm_store_new(engine: *WasmEngine, wasm_error: *WasmError) ?*WasmStore;
extern fn ts_wasm_store_delete(engine: *WasmStore) void;
extern fn ts_wasm_store_load_language(
    store: *WasmStore,
    name: [*c]const u8,
    wasm: [*]const u8,
    wasm_len: u32,
    wasm_error: *WasmError,
) ?*Language;
extern fn ts_wasm_store_language_count(store: *WasmStore) usize;
