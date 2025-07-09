const std = @import("std");

pub const Config = struct {
    listen_addr: []const u8,
    listen_quic_addr: []const u8, // NEW: QUIC endpoint for DoQ
    upstream: []const u8,
    upstream_quic: []const u8, // NEW: QUIC upstream
    blocklist_urls: []const []const u8,
    mode: []const u8, // "udp", "dot", "doh", "doq"
    
    // NEW: Advanced features
    enable_post_quantum: bool,
    enable_zero_copy: bool,
    max_concurrent_queries: usize,
    cache_size: usize,
};

pub fn loadConfig() !Config {
    // Enhanced defaults with QUIC support
    return Config{
        .listen_addr = "0.0.0.0:53",
        .listen_quic_addr = "0.0.0.0:853", // Standard DoQ port
        .upstream = "1.1.1.1:53",
        .upstream_quic = "1.1.1.1:853", // Cloudflare DoQ
        .blocklist_urls = &[_][]const u8{
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/multi.txt",
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt",
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_7.txt",
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_59.txt",
        },
        .mode = "doq", // Default to DNS-over-QUIC for v1.0!
        
        // NEW: Performance and security settings
        .enable_post_quantum = false, // Start with classical, upgrade later
        .enable_zero_copy = true,
        .max_concurrent_queries = 10000,
        .cache_size = 4096,
    };
}

pub fn print_metrics(
    cache_hits: usize, 
    cache_misses: usize, 
    blocked_queries: usize,
    quic_queries: usize,
    udp_queries: usize,
    pq_handshakes: usize,
) void {
    // Enhanced Prometheus-style metrics for v1.0
    std.debug.print("# HELP zigdns_cache_hits Number of DNS cache hits\n", .{});
    std.debug.print("# TYPE zigdns_cache_hits counter\n", .{});
    std.debug.print("zigdns_cache_hits {d}\n", .{cache_hits});
    
    std.debug.print("# HELP zigdns_cache_misses Number of DNS cache misses\n", .{});
    std.debug.print("# TYPE zigdns_cache_misses counter\n", .{});
    std.debug.print("zigdns_cache_misses {d}\n", .{cache_misses});
    
    std.debug.print("# HELP zigdns_blocked_queries Number of blocked DNS queries\n", .{});
    std.debug.print("# TYPE zigdns_blocked_queries counter\n", .{});
    std.debug.print("zigdns_blocked_queries {d}\n", .{blocked_queries});
    
    // NEW: QUIC-specific metrics
    std.debug.print("# HELP zigdns_quic_queries DNS-over-QUIC queries processed\n", .{});
    std.debug.print("# TYPE zigdns_quic_queries counter\n", .{});
    std.debug.print("zigdns_quic_queries {d}\n", .{quic_queries});
    
    std.debug.print("# HELP zigdns_udp_queries Legacy UDP DNS queries\n", .{});
    std.debug.print("# TYPE zigdns_udp_queries counter\n", .{});
    std.debug.print("zigdns_udp_queries {d}\n", .{udp_queries});
    
    std.debug.print("# HELP zigdns_pq_handshakes Post-quantum handshakes completed\n", .{});
    std.debug.print("# TYPE zigdns_pq_handshakes counter\n", .{});
    std.debug.print("zigdns_pq_handshakes {d}\n", .{pq_handshakes});
    
    // Protocol distribution ratio
    const total_queries = quic_queries + udp_queries;
    if (total_queries > 0) {
        const quic_ratio = @as(f64, @floatFromInt(quic_queries)) / @as(f64, @floatFromInt(total_queries));
        std.debug.print("# HELP zigdns_quic_adoption_ratio Percentage of queries using QUIC\n", .{});
        std.debug.print("# TYPE zigdns_quic_adoption_ratio gauge\n", .{});
        std.debug.print("zigdns_quic_adoption_ratio {d:.3}\n", .{quic_ratio});
    }
}
