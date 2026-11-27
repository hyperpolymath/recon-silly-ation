// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// reconcile v0: report-only cross-document consistency checks.
//
// Input is one "reconcile-input/v0" bundle per revision: the repo file list
// plus a docmodel/v0 record for each prose file. Output is findings/v0.
//
// ADR 0002 (owner ruling D152) binds this module:
// - It compares, it never rewrites. No finding carries a fix in v0.
// - Every finding carries evidence (path, rev, span, excerpt).
// - Nothing here touches the filesystem; callers pass bytes in and get
//   bytes out.
//
// Classes in v0:
// - dead-internal-link: a file link or include whose target is not in the
//   repo (error).
// - dead-anchor: a fragment that names no anchor or heading id in the
//   target document (error). Checked only when the target document is in
//   the bundle; otherwise the anchor cannot be judged and is not reported.
//   An AsciiDoc heading also answers to the id GitHub gives it.
// - missing-path-reference: an inline path mention that names no file or
//   directory in the repo (warning; mentions are less certain than links).

const std = @import("std");

pub const Pos = struct { line: u32, col: u32 };
pub const Span = struct { start: Pos, end: Pos };

pub const Heading = struct {
    level: u8,
    text: []const u8,
    id: ?[]const u8 = null,
    span: Span,
};

pub const Anchor = struct { id: []const u8, span: Span };

pub const Link = struct {
    kind: []const u8,
    target: []const u8,
    fragment: ?[]const u8 = null,
    text: ?[]const u8 = null,
    span: Span,
};

pub const Reference = struct { kind: []const u8, value: []const u8, span: Span };

pub const DocModel = struct {
    schema: []const u8,
    repo: []const u8,
    rev: []const u8,
    path: []const u8,
    format: []const u8,
    sha256: []const u8,
    spdx: ?[]const u8 = null,
    title: ?[]const u8 = null,
    headings: []const Heading,
    anchors: []const Anchor,
    links: []const Link,
    references: []const Reference,
};

pub const Bundle = struct {
    schema: []const u8,
    repo: []const u8,
    rev: []const u8,
    files: []const []const u8,
    docs: []const DocModel,
};

pub const Evidence = struct {
    path: []const u8,
    rev: []const u8,
    span: Span,
    excerpt: []const u8,
};

pub const Finding = struct {
    id: []const u8,
    tool: []const u8 = "sillybot",
    class: []const u8,
    severity: []const u8,
    introduced: bool,
    path: []const u8,
    span: Span,
    message: []const u8,
    evidence: []const Evidence,
};

pub const Findings = struct {
    schema: []const u8 = "findings/v0",
    repo: []const u8,
    pr: i64,
    base: []const u8,
    head: []const u8,
    findings: []const Finding,
};

pub const Error = error{ BadSchema, RepoMismatch } || std.mem.Allocator.Error || std.json.ParseError(std.json.Scanner);

const max_excerpt = 400;

/// Parse a reconcile-input/v0 bundle. All memory comes from `arena`.
pub fn parseBundle(arena: std.mem.Allocator, bytes: []const u8) Error!Bundle {
    const b = try std.json.parseFromSliceLeaky(Bundle, arena, bytes, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    if (!std.mem.eql(u8, b.schema, "reconcile-input/v0")) return error.BadSchema;
    for (b.docs) |d| {
        if (!std.mem.eql(u8, d.schema, "docmodel/v0")) return error.BadSchema;
    }
    return b;
}

/// The set of paths that exist: every file, and every directory above one.
const PathSet = struct {
    map: std.StringHashMapUnmanaged(void) = .empty,

    fn init(arena: std.mem.Allocator, files: []const []const u8) !PathSet {
        var s: PathSet = .{};
        for (files) |raw| {
            const f = std.mem.trim(u8, raw, "/");
            try s.map.put(arena, f, {});
            var i: usize = 0;
            while (std.mem.indexOfScalarPos(u8, f, i, '/')) |j| : (i = j + 1) {
                try s.map.put(arena, f[0..j], {});
            }
        }
        return s;
    }

    fn has(s: PathSet, p: []const u8) bool {
        return p.len == 0 or s.map.contains(p);
    }
};

/// Resolve `target` against the directory of `from` (or the repo root when
/// `from` is null or the target starts with '/'). Returns null when the
/// path climbs above the repo root.
pub fn resolve(arena: std.mem.Allocator, from: ?[]const u8, target: []const u8) !?[]const u8 {
    var parts: std.ArrayList([]const u8) = .empty;
    if (from) |f| {
        if (!(target.len > 0 and target[0] == '/')) {
            if (std.mem.lastIndexOfScalar(u8, f, '/')) |k| {
                var it = std.mem.splitScalar(u8, f[0..k], '/');
                while (it.next()) |seg| {
                    if (seg.len != 0) try parts.append(arena, seg);
                }
            }
        }
    }
    var it = std.mem.splitScalar(u8, target, '/');
    while (it.next()) |seg| {
        if (seg.len == 0 or std.mem.eql(u8, seg, ".")) continue;
        if (std.mem.eql(u8, seg, "..")) {
            if (parts.items.len == 0) return null;
            _ = parts.pop();
            continue;
        }
        try parts.append(arena, seg);
    }
    return try std.mem.join(arena, "/", parts.items);
}

fn hasAnchor(arena: std.mem.Allocator, doc: DocModel, id: []const u8) !bool {
    for (doc.anchors) |a| if (std.mem.eql(u8, a.id, id)) return true;
    for (doc.headings) |h| if (h.id) |hid| if (std.mem.eql(u8, hid, id)) return true;
    if (std.mem.eql(u8, doc.format, "asciidoc")) {
        for (try githubAdocIds(arena, doc)) |gid| if (std.mem.eql(u8, gid, id)) return true;
    }
    return false;
}

fn isExplicitAnchor(doc: DocModel, id: []const u8) bool {
    for (doc.anchors) |a| if (std.mem.eql(u8, a.id, id)) return true;
    return false;
}

/// Asciidoctor section id, as docs-ingest makes it: drop simple inline
/// markup, lowercase, keep word characters, space, '-' and '.', join runs
/// of space, '.', '-' (and the separator) with the separator, add the prefix.
fn adocId(arena: std.mem.Allocator, text: []const u8, prefix: []const u8, sep: u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(arena, prefix);
    var in_sep = false;
    var wrote = false;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const c = std.ascii.toLower(text[i]);
        if (c == '<') {
            if (std.mem.indexOfScalarPos(u8, text, i, '>')) |e| {
                i = e;
                continue;
            }
        }
        if (c == '*' or c == '`' or c == '#') continue;
        if (c == ' ' or c == '.' or c == '-' or c == sep) {
            in_sep = true;
            continue;
        }
        if (!(std.ascii.isAlphanumeric(c) or c == '_' or c >= 0x80)) continue;
        if (in_sep and wrote) try out.append(arena, sep);
        in_sep = false;
        wrote = true;
        try out.append(arena, c);
    }
    return out.items;
}

/// The ids GitHub gives a document's AsciiDoc headings. GitHub's renderer
/// (github/markup) sets idprefix '' and idseparator '-' as locked API
/// attributes, and numbers duplicates from 1. So `== Reporting a
/// Vulnerability` is `reporting-a-vulnerability` on GitHub and
/// `_reporting_a_vulnerability` in a default Asciidoctor render, whatever
/// the document's own idprefix and idseparator say. A link that works on
/// GitHub is not dead.
///
/// Headings with no id (sectids off) and headings with an explicit id (also
/// listed as an anchor) get no GitHub form: GitHub uses the same id.
fn githubAdocIds(arena: std.mem.Allocator, doc: DocModel) ![]const []const u8 {
    var bases: std.ArrayList([]const u8) = .empty;
    var out: std.ArrayList([]const u8) = .empty;
    for (doc.headings) |h| {
        const hid = h.id orelse continue;
        if (isExplicitAnchor(doc, hid)) continue;
        const base = try adocId(arena, h.text, "", '-');
        if (base.len == 0) continue;
        var seen: usize = 0;
        for (bases.items) |b| if (std.mem.eql(u8, b, base)) {
            seen += 1;
        };
        try bases.append(arena, base);
        try out.append(arena, if (seen == 0) base else try std.fmt.allocPrint(arena, "{s}-{d}", .{ base, seen }));
    }
    return out.items;
}

/// Compare through a normalising map (ASCII case fold), per ADR 0002: used
/// only to explain a finding, never to clear it or rewrite either side.
fn hasAnchorIgnoringCase(doc: DocModel, id: []const u8) ?[]const u8 {
    for (doc.anchors) |a| if (std.ascii.eqlIgnoreCase(a.id, id)) return a.id;
    for (doc.headings) |h| if (h.id) |hid| if (std.ascii.eqlIgnoreCase(hid, id)) return hid;
    return null;
}

fn findDoc(docs: []const DocModel, path: []const u8) ?DocModel {
    for (docs) |d| if (std.mem.eql(u8, d.path, path)) return d;
    return null;
}

/// A path mention that is a pattern or a placeholder, not a concrete path.
fn isPlaceholder(v: []const u8) bool {
    return std.mem.indexOfAny(u8, v, "*?[]{}<>$") != null or v.len == 0;
}

fn clip(s: []const u8) []const u8 {
    return if (s.len > max_excerpt) s[0..max_excerpt] else s;
}

const Raw = struct {
    class: []const u8,
    severity: []const u8,
    path: []const u8,
    span: Span,
    message: []const u8,
    key: []const u8, // normalised evidence: what the finding is about, without position
    excerpt: []const u8,
};

fn collect(arena: std.mem.Allocator, b: Bundle) ![]Raw {
    const paths = try PathSet.init(arena, b.files);
    var out: std.ArrayList(Raw) = .empty;

    for (b.docs) |doc| {
        for (doc.links) |l| {
            const is_file = std.mem.eql(u8, l.kind, "internal-file") or std.mem.eql(u8, l.kind, "include");
            const is_anchor = std.mem.eql(u8, l.kind, "internal-anchor");
            if (is_file) {
                const shown = if (l.fragment) |fr|
                    try std.fmt.allocPrint(arena, "{s}#{s}", .{ l.target, fr })
                else
                    l.target;
                const resolved = try resolve(arena, doc.path, l.target);
                if (resolved == null or !paths.has(resolved.?)) {
                    const why = if (resolved == null)
                        try std.fmt.allocPrint(arena, "Link target '{s}' climbs above the repository root.", .{l.target})
                    else
                        try std.fmt.allocPrint(arena, "Link target '{s}' resolves to '{s}', which is not in the repository.", .{ l.target, resolved.? });
                    try out.append(arena, .{
                        .class = "dead-internal-link",
                        .severity = "error",
                        .path = doc.path,
                        .span = l.span,
                        .message = why,
                        .key = shown,
                        .excerpt = clip(shown),
                    });
                    continue;
                }
                if (l.fragment) |fr| {
                    if (fr.len == 0) continue;
                    const target_doc = findDoc(b.docs, resolved.?) orelse continue;
                    if (!try hasAnchor(arena, target_doc, fr)) {
                        try out.append(arena, try deadAnchor(arena, doc.path, l.span, resolved.?, fr, target_doc, shown));
                    }
                }
            } else if (is_anchor) {
                var fr = l.fragment orelse l.target;
                if (fr.len > 0 and fr[0] == '#') fr = fr[1..];
                if (fr.len == 0) continue;
                if (!try hasAnchor(arena, doc, fr)) {
                    const shown = try std.fmt.allocPrint(arena, "#{s}", .{fr});
                    try out.append(arena, try deadAnchor(arena, doc.path, l.span, doc.path, fr, doc, shown));
                }
            }
        }
        for (doc.references) |r| {
            if (!std.mem.eql(u8, r.kind, "path")) continue;
            if (isPlaceholder(r.value)) continue;
            const resolved = try resolve(arena, null, r.value);
            if (resolved != null and paths.has(resolved.?)) continue;
            try out.append(arena, .{
                .class = "missing-path-reference",
                .severity = "warning",
                .path = doc.path,
                .span = r.span,
                .message = try std.fmt.allocPrint(arena, "Path '{s}' is mentioned but is not in the repository.", .{r.value}),
                .key = r.value,
                .excerpt = clip(r.value),
            });
        }
    }
    return out.items;
}

fn deadAnchor(arena: std.mem.Allocator, path: []const u8, span: Span, target_path: []const u8, fr: []const u8, target_doc: DocModel, shown: []const u8) !Raw {
    const near = hasAnchorIgnoringCase(target_doc, fr);
    const msg = if (near) |n|
        try std.fmt.allocPrint(arena, "Anchor '{s}' is not defined in '{s}'. '{s}' differs only in letter case; it is reported, not changed.", .{ fr, target_path, n })
    else
        try std.fmt.allocPrint(arena, "Anchor '{s}' is not defined in '{s}'.", .{ fr, target_path });
    return .{
        .class = "dead-anchor",
        .severity = "error",
        .path = path,
        .span = span,
        .message = msg,
        .key = try std.fmt.allocPrint(arena, "{s}#{s}", .{ target_path, fr }),
        .excerpt = clip(shown),
    };
}

fn lessThan(_: void, a: Raw, b: Raw) bool {
    if (!std.mem.eql(u8, a.path, b.path)) return std.mem.lessThan(u8, a.path, b.path);
    if (a.span.start.line != b.span.start.line) return a.span.start.line < b.span.start.line;
    if (a.span.start.col != b.span.start.col) return a.span.start.col < b.span.start.col;
    return std.mem.lessThan(u8, a.class, b.class);
}

/// Stable id: sha256 over tool, class, path, normalised evidence and the
/// occurrence number of that key in the file. Line moves do not change it,
/// so the same finding at the merge base has the same id.
fn makeId(arena: std.mem.Allocator, r: Raw, nth: usize) ![]const u8 {
    var h = std.crypto.hash.sha2.Sha256.init(.{});
    for ([_][]const u8{ "sillybot", r.class, r.path, r.key }) |part| {
        h.update(part);
        h.update(&[_]u8{0});
    }
    h.update(try std.fmt.allocPrint(arena, "{d}", .{nth}));
    var digest: [32]u8 = undefined;
    h.final(&digest);
    const hex = std.fmt.bytesToHex(digest, .lower);
    return try arena.dupe(u8, &hex);
}

fn identify(arena: std.mem.Allocator, raws: []Raw, rev: []const u8, base_ids: ?*const std.StringHashMapUnmanaged(void)) ![]Finding {
    std.mem.sort(Raw, raws, {}, lessThan);
    var seen: std.StringHashMapUnmanaged(usize) = .empty;
    var out = try arena.alloc(Finding, raws.len);
    for (raws, 0..) |r, i| {
        const k = try std.fmt.allocPrint(arena, "{s}\x00{s}\x00{s}", .{ r.class, r.path, r.key });
        const gop = try seen.getOrPut(arena, k);
        if (!gop.found_existing) gop.value_ptr.* = 0;
        const nth = gop.value_ptr.*;
        gop.value_ptr.* += 1;
        const id = try makeId(arena, r, nth);
        const ev = try arena.alloc(Evidence, 1);
        ev[0] = .{ .path = r.path, .rev = rev, .span = r.span, .excerpt = r.excerpt };
        out[i] = .{
            .id = id,
            .class = r.class,
            .severity = r.severity,
            .introduced = if (base_ids) |m| !m.contains(id) else true,
            .path = r.path,
            .span = r.span,
            .message = r.message,
            .evidence = ev,
        };
    }
    return out;
}

/// Run reconcile v0 on a head bundle, and optionally its merge-base bundle.
/// Without a base, every finding counts as introduced and `base` is the
/// head revision. Returns findings/v0 JSON allocated from `arena`.
pub fn run(arena: std.mem.Allocator, head_bytes: []const u8, base_bytes: ?[]const u8, pr: i64) Error![]u8 {
    const head = try parseBundle(arena, head_bytes);
    var base_rev = head.rev;
    var base_ids_store: std.StringHashMapUnmanaged(void) = .empty;
    var base_ids: ?*const std.StringHashMapUnmanaged(void) = null;
    if (base_bytes) |bb| {
        const base = try parseBundle(arena, bb);
        if (!std.mem.eql(u8, base.repo, head.repo)) return error.RepoMismatch;
        base_rev = base.rev;
        const braws = try collect(arena, base);
        const bf = try identify(arena, braws, base.rev, null);
        for (bf) |f| try base_ids_store.put(arena, f.id, {});
        base_ids = &base_ids_store;
    }
    const raws = try collect(arena, head);
    const findings = try identify(arena, raws, head.rev, base_ids);
    const doc: Findings = .{
        .repo = head.repo,
        .pr = pr,
        .base = base_rev,
        .head = head.rev,
        .findings = findings,
    };
    return std.json.Stringify.valueAlloc(arena, doc, .{ .whitespace = .indent_2 });
}

//==============================================================================
// Tests
//==============================================================================

const t = std.testing;

test "resolve relative, absolute and escaping paths" {
    var a = std.heap.ArenaAllocator.init(t.allocator);
    defer a.deinit();
    const ar = a.allocator();
    try t.expectEqualStrings("docs/b.adoc", (try resolve(ar, "docs/a.adoc", "b.adoc")).?);
    try t.expectEqualStrings("README.adoc", (try resolve(ar, "docs/a.adoc", "../README.adoc")).?);
    try t.expectEqualStrings("LICENSE", (try resolve(ar, "docs/a.adoc", "/LICENSE")).?);
    try t.expectEqualStrings("docs/x", (try resolve(ar, "docs/a.adoc", "./x/")).?);
    try t.expect((try resolve(ar, "a.adoc", "../../etc")) == null);
    try t.expectEqualStrings("src/main.zig", (try resolve(ar, null, "./src/main.zig")).?);
}

test "placeholders are not path mentions" {
    try t.expect(isPlaceholder("docs/*.adoc"));
    try t.expect(isPlaceholder("<repo>/README.adoc"));
    try t.expect(isPlaceholder("$HOME/x"));
    try t.expect(!isPlaceholder("docs/guide.adoc"));
}

test "asciidoc headings answer to GitHub ids" {
    var a = std.heap.ArenaAllocator.init(t.allocator);
    defer a.deinit();
    const ar = a.allocator();
    try t.expectEqualStrings("_reporting_a_vulnerability", try adocId(ar, "Reporting a Vulnerability", "_", '_'));
    try t.expectEqualStrings("the-api-v2-guide", try adocId(ar, "The `api.v2` *Guide*", "", '-'));
    const sp: Span = .{ .start = .{ .line = 1, .col = 1 }, .end = .{ .line = 1, .col = 2 } };
    const hs = [_]Heading{
        .{ .level = 1, .text = "Quick Start", .id = "_quick_start", .span = sp },
        .{ .level = 1, .text = "Quick Start", .id = "_quick_start_2", .span = sp },
        .{ .level = 1, .text = "Custom Thing", .id = "custom", .span = sp },
        .{ .level = 1, .text = "Install It", .id = "id_install_it", .span = sp },
        .{ .level = 0, .text = "Title", .span = sp },
    };
    const anchors = [_]Anchor{.{ .id = "custom", .span = sp }};
    var doc: DocModel = .{ .schema = "docmodel/v0", .repo = "o/r", .rev = "r", .path = "a.adoc", .format = "asciidoc", .sha256 = "", .headings = &hs, .anchors = &anchors, .links = &.{}, .references = &.{} };
    for ([_][]const u8{ "quick-start", "quick-start-1", "_quick_start_2", "install-it", "custom" }) |id| try t.expect(try hasAnchor(ar, doc, id));
    for ([_][]const u8{ "quick-start-2", "custom-thing", "title" }) |id| try t.expect(!try hasAnchor(ar, doc, id));
    doc.format = "markdown";
    try t.expect(!try hasAnchor(ar, doc, "quick-start-1"));
}

const sample_head =
    \\{"schema":"reconcile-input/v0","repo":"o/r","rev":"1111111111111111111111111111111111111111",
    \\ "files":["README.adoc","docs/guide.adoc","src/main.zig"],
    \\ "docs":[
    \\  {"schema":"docmodel/v0","repo":"o/r","rev":"1111111111111111111111111111111111111111",
    \\   "path":"README.adoc","format":"asciidoc","sha256":"0000000000000000000000000000000000000000000000000000000000000000",
    \\   "spdx":"CC-BY-SA-4.0","headings":[{"level":1,"text":"Usage","id":"usage","span":{"start":{"line":3,"col":1},"end":{"line":3,"col":9}}}],
    \\   "anchors":[],
    \\   "links":[
    \\    {"kind":"internal-file","target":"docs/guide.adoc","fragment":"install","span":{"start":{"line":5,"col":1},"end":{"line":5,"col":30}}},
    \\    {"kind":"internal-file","target":"docs/gone.adoc","span":{"start":{"line":6,"col":1},"end":{"line":6,"col":30}}},
    \\    {"kind":"internal-anchor","target":"#Usage","span":{"start":{"line":7,"col":1},"end":{"line":7,"col":10}}},
    \\    {"kind":"internal-anchor","target":"#usage","span":{"start":{"line":8,"col":1},"end":{"line":8,"col":10}}},
    \\    {"kind":"external-url","target":"https://example.org/x","span":{"start":{"line":9,"col":1},"end":{"line":9,"col":10}}}
    \\   ],
    \\   "references":[
    \\    {"kind":"path","value":"src/main.zig","span":{"start":{"line":10,"col":1},"end":{"line":10,"col":14}}},
    \\    {"kind":"path","value":"src/old.zig","span":{"start":{"line":11,"col":1},"end":{"line":11,"col":13}}},
    \\    {"kind":"path","value":"docs/*.adoc","span":{"start":{"line":12,"col":1},"end":{"line":12,"col":13}}},
    \\    {"kind":"command","value":"just test","span":{"start":{"line":13,"col":1},"end":{"line":13,"col":10}}}
    \\   ]},
    \\  {"schema":"docmodel/v0","repo":"o/r","rev":"1111111111111111111111111111111111111111",
    \\   "path":"docs/guide.adoc","format":"asciidoc","sha256":"0000000000000000000000000000000000000000000000000000000000000000",
    \\   "spdx":null,"headings":[],"anchors":[{"id":"setup","span":{"start":{"line":2,"col":1},"end":{"line":2,"col":10}}}],
    \\   "links":[],"references":[]}
    \\ ]}
;

test "v0 classes: positives and negatives" {
    var a = std.heap.ArenaAllocator.init(t.allocator);
    defer a.deinit();
    const ar = a.allocator();
    const out = try run(ar, sample_head, null, 7);
    const parsed = try std.json.parseFromSliceLeaky(Findings, ar, out, .{ .ignore_unknown_fields = true });
    // Expect: dead anchor #install in guide, dead link gone.adoc,
    // dead anchor #Usage (case differs), missing src/old.zig. Nothing else.
    try t.expectEqual(@as(usize, 4), parsed.findings.len);
    try t.expectEqualStrings("dead-anchor", parsed.findings[0].class);
    try t.expectEqual(@as(u32, 5), parsed.findings[0].span.start.line);
    try t.expectEqualStrings("dead-internal-link", parsed.findings[1].class);
    try t.expectEqualStrings("dead-anchor", parsed.findings[2].class);
    try t.expect(std.mem.indexOf(u8, parsed.findings[2].message, "letter case") != null);
    try t.expectEqualStrings("missing-path-reference", parsed.findings[3].class);
    try t.expectEqualStrings("warning", parsed.findings[3].severity);
    for (parsed.findings) |f| {
        try t.expect(f.introduced);
        try t.expectEqual(@as(usize, 64), f.id.len);
        try t.expectEqual(@as(usize, 1), f.evidence.len);
    }
}

test "findings present at the base are not introduced, even after a line move" {
    var a = std.heap.ArenaAllocator.init(t.allocator);
    defer a.deinit();
    const ar = a.allocator();
    // The base is the head with every line shifted: ids must still match.
    const base = try std.mem.replaceOwned(u8, ar, sample_head, "\"line\":", "\"line\":1");
    const base2 = try std.mem.replaceOwned(u8, ar, base, "1111111111111111111111111111111111111111", "2222222222222222222222222222222222222222");
    const out = try run(ar, sample_head, base2, 7);
    const parsed = try std.json.parseFromSliceLeaky(Findings, ar, out, .{ .ignore_unknown_fields = true });
    try t.expectEqual(@as(usize, 4), parsed.findings.len);
    for (parsed.findings) |f| try t.expect(!f.introduced);
    try t.expectEqualStrings("2222222222222222222222222222222222222222", parsed.base);
}

test "wrong schema is refused" {
    var a = std.heap.ArenaAllocator.init(t.allocator);
    defer a.deinit();
    try t.expectError(error.BadSchema, run(a.allocator(), "{\"schema\":\"x\",\"repo\":\"o/r\",\"rev\":\"r\",\"files\":[],\"docs\":[]}", null, 0));
}
