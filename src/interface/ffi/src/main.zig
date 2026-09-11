// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// recon_silly_ation FFI Implementation
//
// This module implements the C-compatible FFI declared in src/abi/Foreign.idr
// All types and layouts must match the Idris2 ABI definitions.
//

const std = @import("std");

// Version information (keep in sync with project)
const VERSION = "0.1.0";
const BUILD_INFO = "recon_silly_ation built with Zig " ++ @import("builtin").zig_version_string;

/// Thread-local error storage
threadlocal var last_error: ?[]const u8 = null;

/// Set the last error message
fn setError(msg: []const u8) void {
    last_error = msg;
}

/// Clear the last error
fn clearError() void {
    last_error = null;
}

//==============================================================================
// Core Types (must match src/abi/Types.idr)
//==============================================================================

/// Result codes (must match Idris2 Result type)
pub const Result = enum(c_int) {
    ok = 0,
    @"error" = 1,
    invalid_param = 2,
    out_of_memory = 3,
    null_pointer = 4,
};

/// Library handle (opaque to C callers; the real layout is `HandleImpl` below).
/// Zig's `opaque` types cannot themselves carry fields, so the state lives in
/// `HandleImpl` and we `@ptrCast`/`@alignCast` between the two at the FFI seam.
pub const Handle = opaque {};

const HandleImpl = struct {
    allocator: std.mem.Allocator,
    initialized: bool,
    // Add your fields here
};

fn toImpl(handle: *Handle) *HandleImpl {
    return @ptrCast(@alignCast(handle));
}

fn toHandle(impl: *HandleImpl) *Handle {
    return @ptrCast(impl);
}

//==============================================================================
// Library Lifecycle
//==============================================================================

/// Initialize the library
/// Returns a handle, or null on failure
export fn recon_silly_ation_init() ?*Handle {
    const allocator = std.heap.page_allocator;

    const impl = allocator.create(HandleImpl) catch {
        setError("Failed to allocate handle");
        return null;
    };

    // Initialize handle
    impl.* = .{
        .allocator = allocator,
        .initialized = true,
    };

    clearError();
    return toHandle(impl);
}

/// Free the library handle
export fn recon_silly_ation_free(handle: ?*Handle) void {
    const h = handle orelse return;
    const impl = toImpl(h);
    const allocator = impl.allocator;

    // Clean up resources
    impl.initialized = false;

    allocator.destroy(impl);
    clearError();
}

//==============================================================================
// Core Operations
//==============================================================================

/// Process data (example operation)
export fn recon_silly_ation_process(handle: ?*Handle, input: u32) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };
    const impl = toImpl(h);

    if (!impl.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    // Example processing logic
    _ = input;

    clearError();
    return .ok;
}

//==============================================================================
// String Operations
//==============================================================================

/// Get a string result (example)
/// Caller must free the returned string
export fn recon_silly_ation_get_string(handle: ?*Handle) ?[*:0]const u8 {
    const h = handle orelse {
        setError("Null handle");
        return null;
    };
    const impl = toImpl(h);

    if (!impl.initialized) {
        setError("Handle not initialized");
        return null;
    }

    // Example: allocate and return a string
    const result = impl.allocator.dupeZ(u8, "Example result") catch {
        setError("Failed to allocate string");
        return null;
    };

    clearError();
    return result.ptr;
}

/// Free a string allocated by the library
export fn recon_silly_ation_free_string(str: ?[*:0]const u8) void {
    const s = str orelse return;
    const allocator = std.heap.page_allocator;

    const slice = std.mem.span(s);
    allocator.free(slice);
}

//==============================================================================
// Array/Buffer Operations
//==============================================================================

/// Process an array of data
export fn recon_silly_ation_process_array(
    handle: ?*Handle,
    buffer: ?[*]const u8,
    len: u32,
) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    const buf = buffer orelse {
        setError("Null buffer");
        return .null_pointer;
    };
    const impl = toImpl(h);

    if (!impl.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    // Access the buffer
    const data = buf[0..len];
    _ = data;

    // Process data here

    clearError();
    return .ok;
}

//==============================================================================
// Error Handling
//==============================================================================

/// Get the last error message
/// Returns null if no error
export fn recon_silly_ation_last_error() ?[*:0]const u8 {
    const err = last_error orelse return null;

    // Return C string (static storage, no need to free)
    const allocator = std.heap.page_allocator;
    const c_str = allocator.dupeZ(u8, err) catch return null;
    return c_str.ptr;
}

//==============================================================================
// Version Information
//==============================================================================

/// Get the library version
export fn recon_silly_ation_version() [*:0]const u8 {
    return VERSION.ptr;
}

/// Get build information
export fn recon_silly_ation_build_info() [*:0]const u8 {
    return BUILD_INFO.ptr;
}

//==============================================================================
// Callback Support
//==============================================================================

/// Callback function type (C ABI)
pub const Callback = *const fn (u64, u32) callconv(.c) u32;

/// Register a callback
export fn recon_silly_ation_register_callback(
    handle: ?*Handle,
    callback: ?Callback,
) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    const cb = callback orelse {
        setError("Null callback");
        return .null_pointer;
    };
    const impl = toImpl(h);

    if (!impl.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    // Store callback for later use
    _ = cb;

    clearError();
    return .ok;
}

//==============================================================================
// Utility Functions
//==============================================================================

/// Check if handle is initialized
export fn recon_silly_ation_is_initialized(handle: ?*Handle) u32 {
    const h = handle orelse return 0;
    return if (toImpl(h).initialized) 1 else 0;
}

//==============================================================================
// Tests
//==============================================================================

test "lifecycle" {
    const handle = recon_silly_ation_init() orelse return error.InitFailed;
    defer recon_silly_ation_free(handle);

    try std.testing.expect(recon_silly_ation_is_initialized(handle) == 1);
}

test "error handling" {
    const result = recon_silly_ation_process(null, 0);
    try std.testing.expectEqual(Result.null_pointer, result);

    const err = recon_silly_ation_last_error();
    try std.testing.expect(err != null);
}

test "version" {
    const ver = recon_silly_ation_version();
    const ver_str = std.mem.span(ver);
    try std.testing.expectEqualStrings(VERSION, ver_str);
}
