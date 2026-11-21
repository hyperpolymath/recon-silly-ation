// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// reconcile: command-line front end for reconcile v0.
//
//   reconcile --head HEAD.json [--base BASE.json] [--pr N]
//
// Reads reconcile-input/v0 bundles and prints findings/v0 on stdout.
// Report-only: exit 0 whenever it ran, whatever it found. Exit 2 on a usage,
// read or parse error. It never writes to any file.

const std = @import("std");
const reconcile = @import("reconcile.zig");

const usage = "usage: reconcile --head HEAD.json [--base BASE.json] [--pr N]\n";
const max_input = 64 * 1024 * 1024;

fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt, args);
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    var head_path: ?[]const u8 = null;
    var base_path: ?[]const u8 = null;
    var pr: i64 = 0;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (i + 1 >= args.len) fail("{s}", .{usage});
        if (std.mem.eql(u8, a, "--head")) {
            head_path = args[i + 1];
        } else if (std.mem.eql(u8, a, "--base")) {
            base_path = args[i + 1];
        } else if (std.mem.eql(u8, a, "--pr")) {
            pr = std.fmt.parseInt(i64, args[i + 1], 10) catch fail("reconcile: --pr needs a number\n", .{});
        } else fail("{s}", .{usage});
        i += 1;
    }
    const hp = head_path orelse fail("{s}", .{usage});

    const cwd = std.Io.Dir.cwd();
    const head = cwd.readFileAlloc(io, hp, arena, .limited(max_input)) catch |e|
        fail("reconcile: cannot read {s}: {s}\n", .{ hp, @errorName(e) });
    const base: ?[]const u8 = if (base_path) |bp|
        cwd.readFileAlloc(io, bp, arena, .limited(max_input)) catch |e|
            fail("reconcile: cannot read {s}: {s}\n", .{ bp, @errorName(e) })
    else
        null;

    const out = reconcile.run(arena, head, base, pr) catch |e|
        fail("reconcile: {s}\n", .{@errorName(e)});

    var buf: [4096]u8 = undefined;
    var w = std.Io.File.stdout().writer(io, &buf);
    try w.interface.print("{s}\n", .{out});
    try w.interface.flush();
}
