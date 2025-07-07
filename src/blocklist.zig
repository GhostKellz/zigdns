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

        // For demo purposes, use a static blocklist instead of downloading
        const static_blocklist = [_][]const u8{
            "ads.example.com",
            "tracker.evil.com", 
            "malware.test.org",
            "doubleclick.net",
            "googleadservices.com",
            "facebook.com",
            "analytics.google.com",
        };
        
        for (static_blocklist) |domain| {
            try trie.insert(domain);
        }
        
        // TODO: In production, download from cfg.blocklist_urls
        _ = cfg; // Silence unused parameter warning

        return Blocklist{ .trie = trie };
    }

    pub fn isBlocked(self: *Blocklist, domain: []const u8) bool {
        return self.trie.contains(domain);
    }
};
