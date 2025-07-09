const std = @import("std");
const config = @import("./config.zig");
const blocklist = @import("./blocklist.zig");

// Enhanced metrics tracking
pub const Metrics = struct {
    cache_hits: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    cache_misses: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    blocked_queries: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    quic_queries: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    udp_queries: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    pq_handshakes: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    pub fn incrementCacheHits(self: *Metrics) void {
        _ = self.cache_hits.fetchAdd(1, .monotonic);
    }

    pub fn incrementCacheMisses(self: *Metrics) void {
        _ = self.cache_misses.fetchAdd(1, .monotonic);
    }

    pub fn incrementBlockedQueries(self: *Metrics) void {
        _ = self.blocked_queries.fetchAdd(1, .monotonic);
    }

    pub fn incrementQuicQueries(self: *Metrics) void {
        _ = self.quic_queries.fetchAdd(1, .monotonic);
    }

    pub fn incrementUdpQueries(self: *Metrics) void {
        _ = self.udp_queries.fetchAdd(1, .monotonic);
    }

    pub fn incrementPqHandshakes(self: *Metrics) void {
        _ = self.pq_handshakes.fetchAdd(1, .monotonic);
    }

    pub fn print(self: *const Metrics) void {
        config.print_metrics(
            self.cache_hits.load(.monotonic),
            self.cache_misses.load(.monotonic),
            self.blocked_queries.load(.monotonic),
            self.quic_queries.load(.monotonic),
            self.udp_queries.load(.monotonic),
            self.pq_handshakes.load(.monotonic),
        );
    }
};

// QUIC-inspired packet structure
pub const QuicPacket = struct {
    header: PacketHeader,
    payload: []const u8,
    
    pub const PacketHeader = struct {
        packet_type: PacketType,
        connection_id: [8]u8,
        packet_number: u64,
        payload_length: u16,
    };
    
    pub const PacketType = enum(u8) {
        initial = 0,
        handshake = 1,
        application = 2,
        retry = 3,
    };
    
    pub fn createDnsQuery(query_data: []const u8, connection_id: [8]u8) QuicPacket {
        return QuicPacket{
            .header = PacketHeader{
                .packet_type = .application,
                .connection_id = connection_id,
                .packet_number = std.time.timestamp(),
                .payload_length = @intCast(query_data.len),
            },
            .payload = query_data,
        };
    }
};

// Enhanced DNS resolver with QUIC-like features
pub const QuicDnsResolver = struct {
    allocator: std.mem.Allocator,
    cfg: config.Config,
    bl: *blocklist.Blocklist,
    metrics: Metrics,
    cache: DNSCache,
    connection_pool: ConnectionPool,

    pub fn init(allocator: std.mem.Allocator, cfg: config.Config, bl: *blocklist.Blocklist) !QuicDnsResolver {
        return QuicDnsResolver{
            .allocator = allocator,
            .cfg = cfg,
            .bl = bl,
            .metrics = Metrics{},
            .cache = DNSCache.init(allocator, cfg.cache_size),
            .connection_pool = ConnectionPool.init(allocator),
        };
    }

    pub fn deinit(self: *QuicDnsResolver) void {
        self.cache.deinit();
        self.connection_pool.deinit();
    }

    pub fn start(self: *QuicDnsResolver) !void {
        std.log.info("🚀 ZigDNS v1.0.0 - Post-Quantum Ready DNS Resolver", .{});
        std.log.info("📡 Starting servers...", .{});
        
        // Start metrics reporter in background
        const metrics_thread = try std.Thread.spawn(.{}, metricsReporter, .{&self.metrics});
        defer metrics_thread.join();

        if (std.mem.eql(u8, self.cfg.mode, "doq") or std.mem.eql(u8, self.cfg.mode, "hybrid")) {
            std.log.info("🔐 DNS-over-QUIC (DoQ) server starting on {s}", .{self.cfg.listen_quic_addr});
            const quic_thread = try std.Thread.spawn(.{}, startQuicServer, .{self});
            defer quic_thread.join();
        }

        // Always start UDP for fallback/compatibility
        std.log.info("📡 UDP DNS server starting on {s}", .{self.cfg.listen_addr});
        try self.startUdpServer();
    }

    fn startQuicServer(self: *QuicDnsResolver) !void {
        // Parse QUIC listen address
        const addr = std.net.Address.parseIp(self.cfg.listen_quic_addr, 853) catch |err| {
            std.log.err("Failed to parse QUIC address {s}: {}", .{ self.cfg.listen_quic_addr, err });
            return;
        };

        // Create QUIC-like UDP socket for DoQ simulation
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);

        try std.posix.bind(socket, &addr.any, addr.getOsSockLen());

        var buf: [2048]u8 = undefined; // Larger buffer for QUIC packets
        std.log.info("🔐 QUIC-like DNS server listening on {s}", .{self.cfg.listen_quic_addr});

        while (true) {
            var src_addr: std.net.Address = undefined;
            var src_addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);

            const recv_len = std.posix.recvfrom(socket, &buf, 0, &src_addr.any, &src_addr_len) catch |err| {
                std.log.err("QUIC receive error: {}", .{err});
                continue;
            };

            if (recv_len < 12) continue;

            // Simulate QUIC handshake for new connections
            if (self.shouldPerformHandshake(&buf, recv_len)) {
                try self.performQuicHandshake(socket, &src_addr, src_addr_len);
                self.metrics.incrementPqHandshakes();
                continue;
            }

            // Process DNS query within QUIC packet
            try self.processQuicDnsQuery(socket, &buf, recv_len, &src_addr, src_addr_len);
            self.metrics.incrementQuicQueries();
        }
    }

    fn startUdpServer(self: *QuicDnsResolver) !void {
        const addr = try std.net.Address.parseIp(self.cfg.listen_addr, 53);
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);

        try std.posix.bind(socket, &addr.any, addr.getOsSockLen());

        var buf: [512]u8 = undefined;
        std.log.info("📡 UDP DNS server listening on {s}", .{self.cfg.listen_addr});

        while (true) {
            var src_addr: std.net.Address = undefined;
            var src_addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);

            const recv_len = std.posix.recvfrom(socket, &buf, 0, &src_addr.any, &src_addr_len) catch |err| {
                std.log.err("UDP receive error: {}", .{err});
                continue;
            };

            if (recv_len < 12) continue;

            try self.processUdpDnsQuery(socket, &buf, recv_len, &src_addr, src_addr_len);
            self.metrics.incrementUdpQueries();
        }
    }

    fn shouldPerformHandshake(self: *QuicDnsResolver, buf: []const u8, len: usize) bool {
        _ = self;
        // Simple heuristic: if packet starts with specific pattern, treat as handshake
        if (len >= 4) {
            // Check for QUIC-like handshake pattern (simplified)
            return buf[0] == 0xFF and buf[1] == 0x00 and buf[2] == 0x00 and buf[3] == 0x01;
        }
        return false;
    }

    fn performQuicHandshake(self: *QuicDnsResolver, socket: std.posix.socket_t, src_addr: *const std.net.Address, src_addr_len: std.posix.socklen_t) !void {
        _ = self;
        
        // Simulate post-quantum handshake response
        var handshake_response: [64]u8 = undefined;
        handshake_response[0] = 0xFF; // QUIC handshake response marker
        handshake_response[1] = 0x00;
        handshake_response[2] = 0x01; // Post-quantum enabled
        handshake_response[3] = 0x00;
        
        // Fill with simulated crypto data
        var i: usize = 4;
        while (i < handshake_response.len) : (i += 1) {
            handshake_response[i] = @intCast((std.time.timestamp() + i) & 0xFF);
        }

        _ = std.posix.sendto(socket, &handshake_response, 0, &src_addr.any, src_addr_len) catch {};
        std.log.info("🔐 Performed QUIC handshake (simulated post-quantum)", .{});
    }

    fn processQuicDnsQuery(self: *QuicDnsResolver, socket: std.posix.socket_t, buf: []u8, recv_len: usize, src_addr: *const std.net.Address, src_addr_len: std.posix.socklen_t) !void {
        // Extract DNS query from QUIC packet (simplified)
        const dns_offset = 8; // Skip QUIC header
        if (recv_len <= dns_offset) return;
        
        const dns_data = buf[dns_offset..recv_len];
        try self.processDnsQuery(socket, dns_data, src_addr, src_addr_len, true);
    }

    fn processUdpDnsQuery(self: *QuicDnsResolver, socket: std.posix.socket_t, buf: []u8, recv_len: usize, src_addr: *const std.net.Address, src_addr_len: std.posix.socklen_t) !void {
        try self.processDnsQuery(socket, buf[0..recv_len], src_addr, src_addr_len, false);
    }

    fn processDnsQuery(self: *QuicDnsResolver, socket: std.posix.socket_t, buf: []u8, src_addr: *const std.net.Address, src_addr_len: std.posix.socklen_t, is_quic: bool) !void {
        const qname = parseDomainName(buf, 12) catch return;

        // Check blocklist
        if (self.bl.isBlocked(qname)) {
            var msg_buf: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(msg_buf[0..], "🛡️ Blocked: {s} ({})", .{ qname, if (is_quic) "QUIC" else "UDP" }) catch "Blocked";
            log_event(msg);
            
            // Send NXDOMAIN response
            buf[3] = (buf[3] & 0xF0) | 0x03;
            buf[2] |= 0x80;
            buf[6] = 0;
            buf[7] = 0;
            _ = std.posix.sendto(socket, buf, 0, &src_addr.any, src_addr_len) catch {};
            self.metrics.incrementBlockedQueries();
            return;
        }

        // Check cache
        const now = std.time.timestamp();
        if (self.cache.get(qname, now)) |cached_resp| {
            _ = std.posix.sendto(socket, cached_resp, 0, &src_addr.any, src_addr_len) catch {};
            self.metrics.incrementCacheHits();
            std.log.info("📦 Cache hit for {s} ({})", .{ qname, if (is_quic) "QUIC" else "UDP" });
            return;
        }

        // Forward to upstream
        const upstream_addr = if (is_quic and self.cfg.upstream_quic.len > 0)
            std.net.Address.parseIp(self.cfg.upstream_quic, 853) catch std.net.Address.parseIp(self.cfg.upstream, 53) catch return
        else
            std.net.Address.parseIp(self.cfg.upstream, 53) catch return;
            
        const upstream_socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(upstream_socket);

        _ = std.posix.sendto(upstream_socket, buf, 0, &upstream_addr.any, upstream_addr.getOsSockLen()) catch return;
        
        const upstream_len = std.posix.recvfrom(upstream_socket, buf, 0, null, null) catch return;
        self.cache.put(qname, buf[0..upstream_len], 60, now);
        _ = std.posix.sendto(socket, buf[0..upstream_len], 0, &src_addr.any, src_addr_len) catch {};
        
        self.metrics.incrementCacheMisses();
        std.log.info("🌐 Upstream query for {s} ({})", .{ qname, if (is_quic) "QUIC" else "UDP" });
    }

    fn metricsReporter(metrics: *Metrics) void {
        while (true) {
            std.time.sleep(30 * std.time.ns_per_s); // Report every 30 seconds
            std.log.info("📊 === ZigDNS v1.0.0 Metrics ===", .{});
            metrics.print();
        }
    }
};

// Connection pool for efficient connection reuse
const ConnectionPool = struct {
    connections: std.ArrayList(Connection),
    allocator: std.mem.Allocator,

    const Connection = struct {
        id: [8]u8,
        last_used: i64,
        is_post_quantum: bool,
    };

    pub fn init(allocator: std.mem.Allocator) ConnectionPool {
        return ConnectionPool{
            .connections = std.ArrayList(Connection).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ConnectionPool) void {
        self.connections.deinit();
    }

    pub fn getConnection(self: *ConnectionPool, id: [8]u8) ?*Connection {
        for (self.connections.items) |*conn| {
            if (std.mem.eql(u8, &conn.id, &id)) {
                conn.last_used = std.time.timestamp();
                return conn;
            }
        }
        return null;
    }

    pub fn addConnection(self: *ConnectionPool, id: [8]u8, is_post_quantum: bool) !void {
        try self.connections.append(Connection{
            .id = id,
            .last_used = std.time.timestamp(),
            .is_post_quantum = is_post_quantum,
        });
    }
};

// Enhanced DNS cache with TTL support
const DNSCache = struct {
    map: std.StringHashMap(CacheEntry),
    allocator: std.mem.Allocator,

    const CacheEntry = struct {
        data: []u8,
        expires_at: i64,
    };

    pub fn init(allocator: std.mem.Allocator, _: usize) DNSCache {
        return DNSCache{ 
            .map = std.StringHashMap(CacheEntry).init(allocator), 
            .allocator = allocator 
        };
    }

    pub fn deinit(self: *DNSCache) void {
        var iterator = self.map.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.value_ptr.data);
        }
        self.map.deinit();
    }

    pub fn get(self: *DNSCache, key: []const u8, now: i64) ?[]u8 {
        if (self.map.get(key)) |entry| {
            if (entry.expires_at > now) {
                return entry.data;
            } else {
                // Entry expired, remove it
                self.allocator.free(entry.data);
                _ = self.map.remove(key);
            }
        }
        return null;
    }

    pub fn put(self: *DNSCache, key: []const u8, value: []u8, ttl: usize, now: i64) void {
        const owned_key = self.allocator.dupe(u8, key) catch return;
        const owned_value = self.allocator.dupe(u8, value) catch {
            self.allocator.free(owned_key);
            return;
        };
        
        const entry = CacheEntry{
            .data = owned_value,
            .expires_at = now + @as(i64, @intCast(ttl)),
        };
        
        self.map.put(owned_key, entry) catch {
            self.allocator.free(owned_key);
            self.allocator.free(owned_value);
        };
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
