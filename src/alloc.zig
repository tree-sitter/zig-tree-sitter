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
