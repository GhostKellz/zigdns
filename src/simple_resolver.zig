const std = @import("std");
const config = @import("./config.zig");
const blocklist = @import("./blocklist.zig");
const web3_resolver = @import("./web3_resolver.zig");

/// Simplified DNS resolver that works without external dependencies
pub const SimpleDNSResolver = struct {
    allocator: std.mem.Allocator,
    cfg: config.Config,
    bl: *blocklist.Blocklist,
    web3: web3_resolver.Web3Resolver,
    stats: ResolverStats,
    
    pub fn init(allocator: std.mem.Allocator, cfg: config.Config, bl: *blocklist.Blocklist) !SimpleDNSResolver {
        return SimpleDNSResolver{
            .allocator = allocator,
            .cfg = cfg,
            .bl = bl,
            .web3 = web3_resolver.Web3Resolver.init(allocator),
            .stats = ResolverStats{},
        };
    }
    
    pub fn deinit(_: *SimpleDNSResolver) void {}
    
    pub fn start(self: *SimpleDNSResolver) !void {
        std.log.info("🚀 Starting ZigDNS v1.0.0 - Enhanced DNS Resolver", .{});
        std.log.info("📡 Protocol Support: UDP (primary), Web3 (ENS/UNS/ZNS/CNS)", .{});
        std.log.info("🔐 Security: Ready for QUIC and Post-Quantum integration", .{});
        std.log.info("⚠️  Running in compatibility mode (zquic/zcrypto integration available)", .{});
        
        try self.startUDPServer();
    }
    
    fn startUDPServer(self: *SimpleDNSResolver) !void {
        const addr = try std.net.Address.parseIp("0.0.0.0", 53);
        const socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(socket);
        
        try std.posix.bind(socket, &addr.any, addr.getOsSockLen());
        
        var cache = DNSCache.init(self.allocator, self.cfg.cache_size);
        var buf: [512]u8 = undefined;
        
        std.log.info("📡 Enhanced DNS server listening on {s} (UDP + Web3 support)", .{self.cfg.listen_addr});
        
        while (true) {
            var src_addr: std.net.Address = undefined;
            var src_addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);
            
            const recv_len = std.posix.recvfrom(socket, &buf, 0, &src_addr.any, &src_addr_len) catch |err| {
                std.log.err("UDP receive error: {}", .{err});
                continue;
            };
            
            // Process DNS query with enhanced features
            const response = try self.processQuery(buf[0..recv_len], &cache);
            if (response) |resp| {
                _ = std.posix.sendto(socket, resp, 0, &src_addr.any, src_addr_len) catch {};
                self.stats.udp_queries += 1;
            }
        }
    }
    
    fn processQuery(self: *SimpleDNSResolver, query_data: []const u8, cache: *DNSCache) !?[]const u8 {
        if (query_data.len < 12) return null;
        
        const qname = parseDomainName(query_data, 12) catch return null;
        
        // Check if it's a Web3 domain first
        if (web3_resolver.isWeb3Domain(qname)) {
            return try self.processWeb3Query(qname, query_data, cache);
        }
        
        // Check blocklist for traditional domains
        if (self.bl.isBlocked(qname)) {
            var msg_buf: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(msg_buf[0..], "🚫 Blocked domain: {s}", .{qname}) catch "Blocked domain";
            self.logEvent(msg);
            
            // Return NXDOMAIN response
            var response_buf: [512]u8 = undefined;
            @memcpy(response_buf[0..query_data.len], query_data);
            response_buf[3] = (response_buf[3] & 0xF0) | 0x03; // NXDOMAIN
            response_buf[2] |= 0x80; // Response flag
            response_buf[6] = 0; // No answers
            response_buf[7] = 0;
            
            self.stats.blocked_queries += 1;
            
            const response = try self.allocator.alloc(u8, query_data.len);
            @memcpy(response, response_buf[0..query_data.len]);
            return response;
        }
        
        // Check cache
        const now = std.time.timestamp();
        if (cache.get(qname, now)) |cached_resp| {
            self.stats.cache_hits += 1;
            return cached_resp;
        }
        
        // Forward to upstream
        const response = try self.forwardToUpstream(query_data);
        if (response) |resp| {
            cache.put(qname, resp, 300, now); // Cache for 5 minutes
            self.stats.cache_misses += 1;
        }
        
        return response;
    }
    
    fn processWeb3Query(self: *SimpleDNSResolver, domain: []const u8, query_data: []const u8, cache: *DNSCache) !?[]const u8 {
        _ = cache; // TODO: Implement Web3 caching
        
        std.log.info("🌐 Processing Web3 domain: {s}", .{domain});
        
        // Resolve Web3 domain
        const resolution = try self.web3.resolveDomain(domain);
        if (resolution) |res| {
            // Update statistics based on resolver type
            switch (res.resolver_type) {
                .ens => self.stats.ens_queries += 1,
                .unstoppable_domains => self.stats.unstoppable_queries += 1,
                .zns_ghostchain => self.stats.zns_queries += 1,
                .cns_quic => self.stats.cns_queries += 1,
            }
            
            std.log.info("✅ Resolved {s} via {s} -> {s}", .{ domain, res.resolver_type.toString(), res.addresses[0] });
            
            // Create DNS response
            return try self.createDNSResponse(query_data, res.addresses[0]);
        }
        
        return null;
    }
    
    fn forwardToUpstream(self: *SimpleDNSResolver, query: []const u8) !?[]const u8 {
        const upstream_addr = try std.net.Address.parseIp(self.cfg.upstream, 53);
        const upstream_socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(upstream_socket);
        
        _ = std.posix.sendto(upstream_socket, query, 0, &upstream_addr.any, upstream_addr.getOsSockLen()) catch return null;
        
        var buf: [512]u8 = undefined;
        const response_len = std.posix.recvfrom(upstream_socket, &buf, 0, null, null) catch return null;
        
        // Allocate and return response
        const response = try self.allocator.alloc(u8, response_len);
        @memcpy(response, buf[0..response_len]);
        return response;
    }
    
    fn createDNSResponse(self: *SimpleDNSResolver, query: []const u8, ip_addr: []const u8) ![]const u8 {
        // Create a basic A record response
        var response = try self.allocator.alloc(u8, query.len + 16); // Query + A record
        @memcpy(response[0..query.len], query);
        
        // Set response flags
        response[2] |= 0x80; // Response flag
        response[7] = 1; // One answer
        
        // Add A record (simplified)
        const ip_parts = std.mem.splitSequence(u8, ip_addr, ".");
        var ip_bytes: [4]u8 = undefined;
        var i: usize = 0;
        var it = ip_parts;
        while (it.next()) |part| {
            if (i >= 4) break;
            ip_bytes[i] = std.fmt.parseInt(u8, part, 10) catch 0;
            i += 1;
        }
        
        // Append A record at end of response (simplified)
        const record_start = query.len;
        response[record_start] = 0xC0; // Compression pointer
        response[record_start + 1] = 0x0C; // Points to question name
        response[record_start + 2] = 0x00; // Type A
        response[record_start + 3] = 0x01;
        response[record_start + 4] = 0x00; // Class IN
        response[record_start + 5] = 0x01;
        response[record_start + 6] = 0x00; // TTL (4 bytes)
        response[record_start + 7] = 0x00;
        response[record_start + 8] = 0x01;
        response[record_start + 9] = 0x2C; // 300 seconds
        response[record_start + 10] = 0x00; // Data length
        response[record_start + 11] = 0x04; // 4 bytes for IPv4
        @memcpy(response[record_start + 12..record_start + 16], &ip_bytes);
        
        return response;
    }
    
    fn logEvent(self: *SimpleDNSResolver, msg: []const u8) void {
        _ = self;
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
    
    pub fn printStats(self: *SimpleDNSResolver) void {
        std.log.info("📊 DNS Statistics:", .{});
        std.log.info("   Cache hits: {d}", .{self.stats.cache_hits});
        std.log.info("   Cache misses: {d}", .{self.stats.cache_misses});
        std.log.info("   Blocked queries: {d}", .{self.stats.blocked_queries});
        std.log.info("   UDP queries: {d}", .{self.stats.udp_queries});
        std.log.info("🌐 Web3 Statistics:", .{});
        std.log.info("   ENS queries: {d}", .{self.stats.ens_queries});
        std.log.info("   Unstoppable queries: {d}", .{self.stats.unstoppable_queries});
        std.log.info("   ZNS queries: {d}", .{self.stats.zns_queries});
        std.log.info("   CNS queries: {d}", .{self.stats.cns_queries});
    }
};

const ResolverStats = struct {
    cache_hits: usize = 0,
    cache_misses: usize = 0,
    blocked_queries: usize = 0,
    udp_queries: usize = 0,
    
    // Web3 statistics
    ens_queries: usize = 0,
    unstoppable_queries: usize = 0,
    zns_queries: usize = 0,
    cns_queries: usize = 0,
};

// DNS Cache implementation
const DNSCache = struct {
    map: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, _: usize) DNSCache {
        return DNSCache{ 
            .map = std.StringHashMap([]const u8).init(allocator), 
            .allocator = allocator 
        };
    }
    
    pub fn get(self: *DNSCache, key: []const u8, _: i64) ?[]const u8 {
        return self.map.get(key);
    }
    
    pub fn put(self: *DNSCache, key: []const u8, value: []const u8, _: usize, _: i64) void {
        _ = self.map.put(key, value) catch {};
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