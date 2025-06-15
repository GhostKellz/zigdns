const std = @import("std");

pub const Config = struct {
    listen_addr: []const u8,
    upstream: []const u8,
    blocklist_urls: []const []const u8,
    mode: []const u8, // "udp", "dot", or "doh"
};

pub fn loadConfig() !Config {
    // Hardcoded defaults with multiple vetted blocklists
    return Config{
        .listen_addr = "0.0.0.0:53",
        .upstream = "1.1.1.1:53",
        .blocklist_urls = &[_][]const u8{
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/multi.txt",
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt",
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_7.txt",
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_59.txt",
        },
        .mode = "udp", // Change to "dot" or "doh" as needed
    };
}

pub fn print_metrics(cache_hits: usize, cache_misses: usize, blocked_queries: usize) void {
    // Print Prometheus-style metrics to stdout
    std.debug.print("# HELP zigdns_cache_hits Number of DNS cache hits\n", .{});
    std.debug.print("# TYPE zigdns_cache_hits counter\n", .{});
    std.debug.print("zigdns_cache_hits {d}\n", .{cache_hits});
    std.debug.print("# HELP zigdns_cache_misses Number of DNS cache misses\n", .{});
    std.debug.print("# TYPE zigdns_cache_misses counter\n", .{});
    std.debug.print("zigdns_cache_misses {d}\n", .{cache_misses});
    std.debug.print("# HELP zigdns_blocked_queries Number of blocked DNS queries\n", .{});
    std.debug.print("# TYPE zigdns_blocked_queries counter\n", .{});
    std.debug.print("zigdns_blocked_queries {d}\n", .{blocked_queries});
}
