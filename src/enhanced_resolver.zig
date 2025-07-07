const std = @import("std");
const config = @import("./config.zig");
const blocklist = @import("./blocklist.zig");
const web3_resolver = @import("./web3_resolver.zig");
const security = @import("./security.zig");
const certificates = @import("./certificates.zig");
const zquic = @import("zquic");
const zcrypto = @import("zcrypto");

/// Enhanced DNS resolver with QUIC-inspired features and Web3 support
pub const QuicDNSResolver = struct {
    allocator: std.mem.Allocator,
    cfg: config.Config,
    bl: *blocklist.Blocklist,
    web3: web3_resolver.Web3Resolver,
    
    // Post-quantum security context
    security_ctx: security.DnsSecurityContext,
    secure_cache: security.SecureDnsCache,
    
    // Enhanced statistics
    stats: ResolverStats,
    
    // Connection management (QUIC-inspired)
    connections: std.AutoHashMap(u64, Connection),
    next_connection_id: u64,
    
    pub fn init(allocator: std.mem.Allocator, cfg: config.Config, bl: *blocklist.Blocklist) !QuicDNSResolver {
        var security_ctx = try security.DnsSecurityContext.init(allocator);
        
        // Generate keys if post-quantum is enabled
        if (cfg.enable_post_quantum) {
            try security_ctx.generateSigningKeys();
            try security_ctx.generateKemKeys();
            std.log.info("🔐 Generated post-quantum keys (ML-KEM-768 + ML-DSA-65)", .{});
        }
        
        // Ensure certificates exist for QUIC/TLS
        if (cfg.auto_generate_certs) {
            const cert_path = cfg.cert_path orelse "./certs/zigdns.crt";
            const key_path = cfg.key_path orelse "./certs/zigdns.key";
            certificates.ensureCertificates(allocator, cert_path, key_path, "zigdns.local", &security_ctx) catch |err| {
                std.log.warn("Certificate generation failed: {}", .{err});
            };
        }
        
        var resolver = QuicDNSResolver{
            .allocator = allocator,
            .cfg = cfg,
            .bl = bl,
            .web3 = web3_resolver.Web3Resolver.init(allocator),
            .security_ctx = security_ctx,
            .secure_cache = undefined, // Will be initialized after struct creation
            .stats = ResolverStats{},
            .connections = std.AutoHashMap(u64, Connection).init(allocator),
            .next_connection_id = 1,
        };
        
        // Initialize secure cache after the struct is created
        resolver.secure_cache = security.SecureDnsCache.init(&resolver.security_ctx);
        
        return resolver;
    }
    
    pub fn deinit(self: *QuicDNSResolver) void {
        self.security_ctx.deinit();
        self.secure_cache.deinit();
        self.connections.deinit();
    }
    
    pub fn start(self: *QuicDNSResolver) !void {
        std.log.info("🚀 Starting ZigDNS v1.0.0 - Post-Quantum Web3 DNS Resolver", .{});
        std.log.info("📡 Protocol Support: UDP (legacy), DoQ (primary), Web3 (ENS/UNS/ZNS/CNS)", .{});
        std.log.info("🔐 Security: Post-Quantum Ready, QUIC-inspired transport", .{});
        
        // Start both UDP and QUIC servers concurrently
        var threads: [2]std.Thread = undefined;
        
        // Start UDP server for legacy support
        threads[0] = try std.Thread.spawn(.{}, startUDPServerThread, .{self});
        
        // Start QUIC server for DNS-over-QUIC (DoQ)
        threads[1] = try std.Thread.spawn(.{}, startQuicServerThread, .{self});
        
        // Wait for both servers
        for (threads) |thread| {
            thread.join();
        }
    }
    
    fn startUDPServerThread(self: *QuicDNSResolver) void {
        self.startUDPServer() catch |err| {
            std.log.err("UDP server error: {}", .{err});
        };
    }
    
    fn startQuicServerThread(self: *QuicDNSResolver) void {
        self.startQuicServer() catch |err| {
            std.log.err("QUIC server error: {}", .{err});
        };
    }
    
    fn startQuicServer(self: *QuicDNSResolver) !void {
        std.log.info("🚀 Starting DNS-over-QUIC server on {s} (Post-Quantum Ready)", .{self.cfg.listen_quic_addr});
        
        // Initialize ZQUIC library
        try zquic.init(self.allocator);
        defer zquic.deinit();
        
        // Configure CNS resolver for DNS-over-QUIC with post-quantum security
        const quic_config = zquic.CnsResolverConfig{
            .server_address = self.cfg.listen_quic_addr,
            .upstream_servers = &[_][]const u8{
                self.cfg.upstream_quic, // Use QUIC upstream
                self.cfg.upstream,      // Fallback to UDP
                "8.8.8.8:53",
                "1.1.1.1:53",
            },
            .cache_size = self.cfg.cache_size,
            .enable_dnssec = true,
            .blockchain_domains = true,
            .blockchain_endpoints = &[_][]const u8{
                "https://mainnet.infura.io/v3/YOUR_KEY",
                "https://rpc.ghostchain.io",
            },
            .tls_config = .{
                .cert_path = self.cfg.cert_path orelse "./certs/zigdns.crt",
                .key_path = self.cfg.key_path orelse "./certs/zigdns.key",
                .enable_post_quantum = self.cfg.enable_post_quantum,
                .cipher_suites = if (self.cfg.enable_post_quantum) &[_][]const u8{
                    "TLS_AES_256_GCM_SHA384_KYBER768",
                    "TLS_CHACHA20_POLY1305_SHA256_KYBER512",
                } else &[_][]const u8{
                    "TLS_AES_256_GCM_SHA384",
                    "TLS_CHACHA20_POLY1305_SHA256",
                },
            },
            .rate_limit = .{
                .requests_per_second = 1000,
                .by_ip = true,
            },
        };
        
        // Initialize QUIC-based DNS resolver
        var quic_resolver = zquic.CnsResolver.init(self.allocator, quic_config) catch |err| {
            std.log.err("Failed to initialize QUIC DNS resolver: {}", .{err});
            return;
        };
        defer quic_resolver.deinit();
        
        // Add middleware for enhanced functionality
        // Note: Simplified approach for now - will integrate middleware when ZQUIC supports it
        
        // Start QUIC DNS resolver
        quic_resolver.start() catch |err| {
            std.log.err("Failed to start QUIC DNS resolver: {}", .{err});
        };
    }
    
    fn quicMiddleware(self: *QuicDNSResolver, ctx: *zquic.Context, next: zquic.NextFn) !void {
        const start_time = std.time.nanoTimestamp();
        
        // Check if it's a Web3 domain
        if (web3_resolver.isWeb3Domain(ctx.question.name)) {
            try self.handleWeb3Query(ctx);
        } else {
            // Check blocklist
            if (self.bl.isBlocked(ctx.question.name)) {
                ctx.response.header.flags.rcode = 3; // NXDOMAIN
                self.stats.blocked_queries += 1;
                self.logBlockedQuery(ctx.question.name);
                return;
            }
            
            // Process normal DNS query
            try next(ctx);
        }
        
        // Update statistics
        const duration = std.time.nanoTimestamp() - start_time;
        self.stats.quic_queries += 1;
        
        // Check if post-quantum was used
        if (self.cfg.enable_post_quantum) {
            self.stats.pq_handshakes += 1;
        }
        
        std.log.debug("QUIC query: {s} took {}ms (PQ: {})", .{ 
            ctx.question.name, 
            duration / std.time.ns_per_ms,
            self.cfg.enable_post_quantum,
        });
    }
    
    fn handleWeb3Query(self: *QuicDNSResolver, ctx: *zquic.Context) !void {
        const resolution = try self.web3.resolveDomain(ctx.question.name);
        if (resolution) |res| {
            // Convert Web3 resolution to DNS response
            ctx.response.header.flags.qr = true; // Response
            ctx.response.header.flags.aa = true; // Authoritative
            ctx.response.header.ancount = @intCast(res.addresses.len);
            
            // Add A records for each address
            for (res.addresses) |addr| {
                const record = zquic.DnsRecord{
                    .name = try self.allocator.dupe(u8, ctx.question.name),
                    .type = .A,
                    .class = .IN,
                    .ttl = res.ttl,
                    .rdata = .{ .a = try parseIPv4(addr) },
                };
                try ctx.response.answers.append(record);
            }
            
            // Update Web3 statistics
            switch (res.resolver_type) {
                .ens => self.stats.ens_queries += 1,
                .unstoppable_domains => self.stats.unstoppable_queries += 1,
                .zns_ghostchain => self.stats.zns_queries += 1,
                .cns_quic => self.stats.cns_queries += 1,
            }
        }
    }
    
    fn logBlockedQuery(self: *QuicDNSResolver, domain: []const u8) void {
        var msg_buf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(msg_buf[0..], "🚫 Blocked QUIC query: {s}", .{domain}) catch "Blocked QUIC query";
        self.logEvent(msg);
    }
    
    fn parseIPv4(ip_str: []const u8) !std.net.Address {
        return std.net.Address.parseIp4(ip_str, 0) catch std.net.Address.parseIp4("0.0.0.0", 0);
    }

    fn startUDPServer(self: *QuicDNSResolver) !void {
        // Parse address and port from listen_addr
        const addr_str = "0.0.0.0"; // Extract from config if needed
        const addr = try std.net.Address.parseIp(addr_str, 53);
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
            const response = try self.processQuery(buf[0..recv_len], .udp, &cache);
            if (response) |resp| {
                _ = std.posix.sendto(socket, resp, 0, &src_addr.any, src_addr_len) catch {};
                self.stats.udp_queries += 1;
            }
        }
    }
    
    fn processQuery(self: *QuicDNSResolver, query_data: []const u8, protocol: Protocol, cache: *DNSCache) !?[]const u8 {
        if (query_data.len < 12) return null;
        
        const qname = parseDomainName(query_data, 12) catch return null;
        
        // Check if it's a Web3 domain first
        if (web3_resolver.isWeb3Domain(qname)) {
            return try self.processWeb3Query(qname, query_data, protocol, cache);
        }
        
        // Check blocklist for traditional domains
        if (self.bl.isBlocked(qname)) {
            var msg_buf: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(msg_buf[0..], "🚫 Blocked {s} domain: {s}", .{ protocol.toString(), qname }) catch "Blocked domain";
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
        
        // Check cache (use secure cache if post-quantum is enabled)
        if (self.cfg.enable_post_quantum) {
            if (self.secure_cache.retrieve(qname)) |cached_resp| {
                self.stats.cache_hits += 1;
                const response = try self.allocator.dupe(u8, cached_resp);
                return response;
            } else |_| {
                // Cache miss or invalid signature
                self.stats.cache_misses += 1;
            }
        } else {
            const now = std.time.timestamp();
            if (cache.get(qname, now)) |cached_resp| {
                self.stats.cache_hits += 1;
                return cached_resp;
            }
        }
        
        // Forward to upstream
        const response = try self.forwardToUpstream(query_data, protocol);
        if (response) |resp| {
            // Cache response (use secure cache if post-quantum is enabled)
            if (self.cfg.enable_post_quantum) {
                self.secure_cache.store(qname, resp, 300) catch |err| {
                    std.log.warn("Failed to store in secure cache: {}", .{err});
                };
            } else {
                const now = std.time.timestamp();
                cache.put(qname, resp, 300, now); // Cache for 5 minutes
            }
            
            if (!self.cfg.enable_post_quantum) {
                self.stats.cache_misses += 1;
            }
        }
        
        return response;
    }
    
    fn processWeb3Query(self: *QuicDNSResolver, domain: []const u8, query_data: []const u8, protocol: Protocol, cache: *DNSCache) !?[]const u8 {
        _ = cache; // TODO: Implement Web3 caching
        
        std.log.info("🌐 Processing Web3 domain: {s} via {s}", .{ domain, protocol.toString() });
        
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
    
    fn forwardToUpstream(self: *QuicDNSResolver, query: []const u8, protocol: Protocol) !?[]const u8 {
        _ = protocol; // TODO: Use appropriate upstream based on protocol
        
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
    
    fn createDNSResponse(self: *QuicDNSResolver, query: []const u8, ip_addr: []const u8) ![]const u8 {
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
    
    fn logEvent(self: *QuicDNSResolver, msg: []const u8) void {
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
};

const Protocol = enum {
    udp,
    quic,
    
    fn toString(self: Protocol) []const u8 {
        return switch (self) {
            .udp => "UDP",
            .quic => "QUIC",
        };
    }
};

const Connection = struct {
    id: u64,
    remote_addr: std.net.Address,
    created_at: i64,
    last_activity: i64,
    packets_sent: u64,
    packets_received: u64,
};

const ResolverStats = struct {
    cache_hits: usize = 0,
    cache_misses: usize = 0,
    blocked_queries: usize = 0,
    quic_queries: usize = 0,
    udp_queries: usize = 0,
    pq_handshakes: usize = 0,
    
    // Web3 statistics
    ens_queries: usize = 0,
    unstoppable_queries: usize = 0,
    zns_queries: usize = 0,
    cns_queries: usize = 0,
    web3_cache_hits: usize = 0,
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
