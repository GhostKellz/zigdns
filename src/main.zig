const std = @import("std");
const config = @import("./config.zig");
const blocklist = @import("./blocklist.zig");
const ZigResolver = @import("./ZigResolver.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("🚀 ZigDNS v1.0.0 - Production DNS Resolver\n", .{});
    try stdout.print("🎯 Mission: Replace Unbound with Superior Performance\n", .{});
    try stdout.print("🔥 Features: SIMD, Hierarchical Cache, Intelligent LB, DNSSEC, Web3\n\n", .{});

    const allocator = std.heap.page_allocator;

    const cfg = try config.loadConfig();
    std.log.info("⚙️  Configuration loaded - Mode: {s}", .{cfg.mode});
    
    var bl = try blocklist.Blocklist.init(cfg, allocator);
    std.log.info("🛡️  Blocklist initialized with static entries", .{});

    var resolver = try ZigResolver.ProductionDNSResolver.init(allocator, cfg);
    defer resolver.deinit();
    
    // Set blocklist reference
    resolver.blocklist = &bl;
    
    std.log.info("🔥 ZigDNS v1.0.0 Production Resolver initialized", .{});
    std.log.info("📊 Performance targets vs Unbound:", .{});
    std.log.info("   ⚡ Queries/sec: 500k+ (vs 100k)", .{});
    std.log.info("   💾 Memory: 20MB (vs 50MB)", .{});
    std.log.info("   🚀 Startup: 200ms (vs 2s)", .{});
    std.log.info("   🎯 Cache Hit: 95%+ (vs 85%)", .{});

    try resolver.start();
}
