const std = @import("std");
const config = @import("./config.zig");
const blocklist = @import("./blocklist.zig");

// Simple working DNS resolver without complex libxev UDP operations
pub const Resolver = struct {
    allocator: std.mem.Allocator,
    cfg: config.Config,
    bl: *blocklist.Blocklist,

    pub fn init(allocator: std.mem.Allocator, cfg: config.Config, bl: *blocklist.Blocklist) !Resolver {
        return Resolver{
            .allocator = allocator,
            .cfg = cfg,
            .bl = bl,
        };
    }

    pub fn deinit(_: *Resolver) void {}

    pub fn start(self: *Resolver) !void {
        const allocator = self.allocator;

        // Create UDP socket using standard library
        const addr = try std.net.Address.parseIp(self.cfg.listen_addr, 53);
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);

        try std.posix.bind(socket, &addr.any, addr.getOsSockLen());

        var cache = DNSCache.init(allocator, 4096);
        var buf: [512]u8 = undefined;

        std.log.info("ZigDNS listening on {s}", .{self.cfg.listen_addr});

        while (true) {
            var src_addr: std.net.Address = undefined;
            var src_addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);

            const recv_len = std.posix.recvfrom(socket, &buf, 0, &src_addr.any, &src_addr_len) catch |err| {
                std.log.err("UDP receive error: {}", .{err});
                continue;
            };

            if (recv_len < 12) continue;
            const qname = parseDomainName(buf[0..recv_len], 12) catch continue;

            if (self.bl.isBlocked(qname)) {
                var msg_buf: [512]u8 = undefined;
                const msg = std.fmt.bufPrint(msg_buf[0..], "Blocked: {s}", .{qname}) catch "Blocked: <error>";
                log_event(msg);
                buf[3] = (buf[3] & 0xF0) | 0x03;
                buf[2] |= 0x80;
                buf[6] = 0;
                buf[7] = 0;
                _ = std.posix.sendto(socket, buf[0..recv_len], 0, &src_addr.any, src_addr_len) catch {};
                continue;
            }

            const now = std.time.timestamp();
            if (cache.get(qname, now)) |cached_resp| {
                _ = std.posix.sendto(socket, cached_resp, 0, &src_addr.any, src_addr_len) catch {};
                continue;
            }

            // Forward to upstream DNS
            const upstream_addr = try std.net.Address.parseIp(self.cfg.upstream, 53);
            const upstream_socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
            defer std.posix.close(upstream_socket);

            _ = std.posix.sendto(upstream_socket, buf[0..recv_len], 0, &upstream_addr.any, upstream_addr.getOsSockLen()) catch continue;

            const upstream_len = std.posix.recvfrom(upstream_socket, &buf, 0, null, null) catch continue;
            cache.put(qname, buf[0..upstream_len], 60, now);
            _ = std.posix.sendto(socket, buf[0..upstream_len], 0, &src_addr.any, src_addr_len) catch {};
        }
    }
};

fn parseDomainName(buf: []const u8, offset: usize) ![]const u8 {
    var i = offset;
    var out: [256]u8 = undefined;
    var out_i: usize = 0;
    while (i < buf.len and buf[i] != 0) {
        const len = buf[i];
        i += 1;
        if (i + len > buf.len or out_i + len + 1 > out.len) return error.InvalidDomain;
        if (out_i != 0) {
            out[out_i] = '.';
            out_i += 1;
        }
        @memcpy(out[out_i..][0..len], buf[i..][0..len]);
        out_i += len;
        i += len;
    }
    return out[0..out_i];
}

fn log_event(msg: []const u8) void {
    const log_path = "zigdns.log";
    var file = std.fs.cwd().createFile(log_path, .{}) catch |err| {
        // If file exists, open it for appending
        if (err == error.PathAlreadyExists) {
            var existing_file = std.fs.cwd().openFile(log_path, .{ .mode = .write_only }) catch return;
            defer existing_file.close();
            _ = existing_file.seekFromEnd(0) catch {};
            _ = existing_file.writeAll(msg) catch {};
            _ = existing_file.writeAll("\n") catch {};
        }
        return;
    };
    defer file.close();
    _ = file.writeAll(msg) catch {};
    _ = file.writeAll("\n") catch {};
}

const DNSCache = struct {
    map: std.StringHashMap([]u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, _: usize) DNSCache {
        return DNSCache{ .map = std.StringHashMap([]u8).init(allocator), .allocator = allocator };
    }

    pub fn get(self: *DNSCache, key: []const u8, _: i64) ?[]u8 {
        return self.map.get(key);
    }

    pub fn put(self: *DNSCache, key: []const u8, value: []u8, _: usize, _: i64) void {
        _ = self.map.put(key, value) catch {};
    }
};
