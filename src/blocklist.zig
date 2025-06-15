const std = @import("std");
const config = @import("./config.zig");

pub const TrieNode = struct {
    children: std.AutoHashMap(u8, *TrieNode),
    is_end: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TrieNode {
        return TrieNode{
            .children = std.AutoHashMap(u8, *TrieNode).init(allocator),
            .is_end = false,
            .allocator = allocator,
        };
    }

    pub fn insert(self: *TrieNode, word: []const u8) !void {
        var node = self;
        for (word) |c| {
            if (!node.children.contains(c)) {
                const child = try self.allocator.create(TrieNode);
                child.* = TrieNode.init(self.allocator);
                try node.children.put(c, child);
            }
            node = node.children.get(c).?;
        }
        node.is_end = true;
    }

    pub fn contains(self: *TrieNode, word: []const u8) bool {
        var node = self;
        for (word) |c| {
            node = node.children.get(c) orelse return false;
        }
        return node.is_end;
    }
};

pub const Blocklist = struct {
    trie: TrieNode,

    pub fn init(cfg: config.Config, allocator: std.mem.Allocator) !Blocklist {
        var trie = TrieNode.init(allocator);

        for (cfg.blocklist_urls) |url| {
            const uri = try std.Uri.parse(url);
            var client = std.http.Client{ .allocator = allocator };
            defer client.deinit();

            var header_buf: [4096]u8 = undefined;
            var req = try client.open(.GET, uri, .{ .server_header_buffer = &header_buf });
            try req.send();

            const body = try req.reader().readAllAlloc(allocator, 10_000_000);
            defer allocator.free(body);

            var lines = std.mem.splitScalar(u8, body, '\n');
            while (lines.next()) |line| {
                const trimmed = std.mem.trim(u8, line, " \t\r");
                if (trimmed.len == 0 or trimmed[0] == '#') continue;

                if (std.mem.startsWith(u8, trimmed, "0.0.0.0 ") or
                    std.mem.startsWith(u8, trimmed, "127.0.0.1 "))
                {
                    var parts = std.mem.splitScalar(u8, trimmed, ' ');
                    _ = parts.next(); // skip IP
                    if (parts.next()) |domain| {
                        try trie.insert(domain);
                    }
                }
            }
        }

        return Blocklist{ .trie = trie };
    }

    pub fn isBlocked(self: *Blocklist, domain: []const u8) bool {
        return self.trie.contains(domain);
    }
};
