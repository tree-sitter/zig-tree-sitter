const std = @import("std");
/// Set the allocation functions used by the library.
///
/// By default, Tree-sitter uses the standard libc allocation functions,
/// but aborts the process when an allocation fails. This function lets
/// you supply alternative allocation functions at runtime.
///
/// If you pass `null` for any parameter, Tree-sitter will switch back to
/// its default implementation of that function.
///
/// If you call this function after the library has already been used, then
/// you must ensure that either:
///  1. All the existing objects have been freed.
///  2. The new allocator shares its state with the old one, so it is capable
///     of freeing memory that was allocated by the old allocator.
pub extern fn ts_set_allocator(
    new_malloc: ?*const fn (size: usize) callconv(.C) ?*anyopaque,
    new_calloc: ?*const fn (nmemb: usize, size: usize) callconv(.C) ?*anyopaque,
    new_realloc: ?*const fn (ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque,
    new_free: ?*const fn (ptr: ?*anyopaque) callconv(.C) void,
) void;

var ts_allocator: ?std.mem.Allocator = null;

/// Mapping of allocated pointer lengths.
var alloc_registry: ?std.AutoHashMap(usize, usize) = null;

var mutex = std.Thread.Mutex{};

fn malloc(size: usize) callconv(.C) ?*anyopaque {
    mutex.lock();
    defer mutex.unlock();

    if (ts_allocator.?.alloc(u8, size)) |slice| {
        alloc_registry.?.put(@intFromPtr(slice.ptr), slice.len) catch {
            ts_allocator.?.free(slice);
            return null;
        };

        return @ptrCast(slice);
    } else |_| {
        return null;
    }
}

fn calloc(nmemb: usize, size: usize) callconv(.C) ?*anyopaque {
    mutex.lock();
    defer mutex.unlock();

    if (ts_allocator.?.alloc(u8, nmemb * size)) |new_mem| {
        alloc_registry.?.put(@intFromPtr(new_mem.ptr), new_mem.len) catch {
            ts_allocator.?.free(new_mem);
            return null;
        };

        @memset(new_mem, 0);

        return @ptrCast(new_mem);
    } else |_| {
        return null;
    }
}

fn realloc(maybe_ptr: ?*anyopaque, new_size: usize) callconv(.C) ?*anyopaque {
    if (maybe_ptr) |old_ptr| {
        mutex.lock();
        defer mutex.unlock();

        if (alloc_registry.?.get(@intFromPtr(old_ptr))) |old_size| {
            var old_mem: []u8 = undefined;
            old_mem.ptr = @ptrCast(old_ptr);
            old_mem.len = old_size;

            if (ts_allocator.?.realloc(old_mem, new_size)) |new_mem| {
                const removed = alloc_registry.?.remove(@intFromPtr(old_ptr));
                std.debug.assert(removed == true);

                if (new_mem.len == 0) return null; // freed old mem

                alloc_registry.?.put(@intFromPtr(new_mem.ptr), new_mem.len) catch {
                    ts_allocator.?.free(new_mem);
                    return null;
                };

                return @ptrCast(new_mem);
            } else |_| {
                return null;
            }
        }
    }

    return malloc(new_size);
}

fn free(maybe_ptr: ?*anyopaque) callconv(.C) void {
    mutex.lock();
    defer mutex.unlock();
    if (maybe_ptr) |ptr| {
        if (alloc_registry.?.fetchRemove(@intFromPtr(ptr))) |kv| {
            var slice: []u8 = undefined;
            slice.ptr = @ptrCast(ptr);
            slice.len = kv.value;

            ts_allocator.?.free(slice);
        }
    }
}

/// Wrapper for `ts_set_allocator`. Overrides Tree-sitter's default libc
/// allocation functions with ones backed by a Zig `std.mem.Allocator`.
/// The caller is responsible for calling `unsetAllocator` to free
/// map of stored adress lengths.
pub fn setAllocator(gpa: std.mem.Allocator) void {
    alloc_registry = std.AutoHashMap(usize, usize).init(gpa);
    ts_allocator = gpa;
    ts_set_allocator(malloc, calloc, realloc, free);
}

/// Make Tree-sitter switch back to using libc allocation
/// functions and free stored map of allocated address lengths.
pub fn unsetAllocator() void {
    if (alloc_registry != null) {
        alloc_registry.?.deinit();
        alloc_registry = null;
    }
    ts_allocator = null;
    ts_set_allocator(null, null, null, null);
}
