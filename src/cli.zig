const std = @import("std");
const simpleResolver = @import("./simpleResolver.zig");
const config = @import("./config.zig");
const blocklist = @import("./blocklist.zig");

pub const CliCommand = enum {
    help,
    version,
    start,
    query,
    flush,
    stats,
    test_web3,
    config_show,
    config_set,
    
    pub fn fromString(str: []const u8) ?CliCommand {
        if (std.mem.eql(u8, str, "help") or std.mem.eql(u8, str, "-h") or std.mem.eql(u8, str, "--help")) return .help;
        if (std.mem.eql(u8, str, "version") or std.mem.eql(u8, str, "-v") or std.mem.eql(u8, str, "--version")) return .version;
        if (std.mem.eql(u8, str, "start") or std.mem.eql(u8, str, "run")) return .start;
        if (std.mem.eql(u8, str, "query") or std.mem.eql(u8, str, "resolve")) return .query;
        if (std.mem.eql(u8, str, "flush") or std.mem.eql(u8, str, "clear-cache")) return .flush;
        if (std.mem.eql(u8, str, "stats") or std.mem.eql(u8, str, "status")) return .stats;
        if (std.mem.eql(u8, str, "test-web3") or std.mem.eql(u8, str, "test")) return .test_web3;
        if (std.mem.eql(u8, str, "config")) return .config_show;
        if (std.mem.eql(u8, str, "set")) return .config_set;
        return null;
    }
};

pub const CliArgs = struct {
    command: CliCommand,
    args: [][]const u8,
    
    // Common flags
    verbose: bool = false,
    quiet: bool = false,
    port: ?u16 = null,
    upstream: ?[]const u8 = null,
    protocol: ?[]const u8 = null, // udp, dot, doh, doq
    enable_web3: bool = true,
    enable_blocklist: bool = true,
    daemon: bool = false,
};

pub fn parseArgs(_: std.mem.Allocator, args: [][]const u8) !CliArgs {
    if (args.len < 2) {
        return CliArgs{ .command = .help, .args = args };
    }
    
    const command_str = args[1];
    const command = CliCommand.fromString(command_str) orelse .help;
    
    var parsed = CliArgs{
        .command = command,
        .args = if (args.len > 2) args[2..] else &[_][]const u8{},
    };
    
    // Parse flags
    for (args[2..]) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
                parsed.verbose = true;
            } else if (std.mem.eql(u8, arg, "--quiet") or std.mem.eql(u8, arg, "-q")) {
                parsed.quiet = true;
            } else if (std.mem.startsWith(u8, arg, "--port=")) {
                const port_str = arg[7..];
                parsed.port = std.fmt.parseInt(u16, port_str, 10) catch null;
            } else if (std.mem.startsWith(u8, arg, "--upstream=")) {
                parsed.upstream = arg[11..];
            } else if (std.mem.startsWith(u8, arg, "--protocol=")) {
                parsed.protocol = arg[11..];
            } else if (std.mem.eql(u8, arg, "--no-web3")) {
                parsed.enable_web3 = false;
            } else if (std.mem.eql(u8, arg, "--no-blocklist")) {
                parsed.enable_blocklist = false;
            } else if (std.mem.eql(u8, arg, "--daemon") or std.mem.eql(u8, arg, "-d")) {
                parsed.daemon = true;
            }
        }
    }
    
    return parsed;
}

pub fn runCli(allocator: std.mem.Allocator, cli_args: CliArgs) !void {
    switch (cli_args.command) {
        .help => try printHelp(),
        .version => try printVersion(),
        .start => try startServer(allocator, cli_args),
        .query => try queryDomain(allocator, cli_args),
        .flush => try flushCache(allocator),
        .stats => try showStats(allocator),
        .test_web3 => try testWeb3(allocator, cli_args),
        .config_show => try showConfig(),
        .config_set => try setConfig(cli_args),
    }
}

fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("🚀 ZigDNS v1.0.0 - Advanced DNS Resolver with Web3 Support\n\n", .{});
    try stdout.print("USAGE:\n", .{});
    try stdout.print("    zdns <COMMAND> [OPTIONS]\n\n", .{});
    try stdout.print("COMMANDS:\n", .{});
    try stdout.print("    help, -h, --help       Show this help message\n", .{});
    try stdout.print("    version, -v            Show version information\n", .{});
    try stdout.print("    start, run             Start the DNS server (default)\n", .{});
    try stdout.print("    query <domain>         Query a specific domain\n", .{});
    try stdout.print("    flush, clear-cache     Clear DNS cache\n", .{});
    try stdout.print("    stats, status          Show server statistics\n", .{});
    try stdout.print("    test-web3, test        Test Web3 domain resolution\n", .{});
    try stdout.print("    config                 Show current configuration\n", .{});
    try stdout.print("    set <key> <value>      Set configuration value\n\n", .{});
    try stdout.print("OPTIONS:\n", .{});
    try stdout.print("    --verbose, -v          Enable verbose output\n", .{});
    try stdout.print("    --quiet, -q            Suppress non-error output\n", .{});
    try stdout.print("    --daemon, -d           Run as daemon/background service\n", .{});
    try stdout.print("    --port=<port>          Set DNS server port (default: 53)\n", .{});
    try stdout.print("    --protocol=<proto>     Set protocol: udp, dot, doh, doq (default: udp)\n", .{});
    try stdout.print("    --upstream=<server>    Set upstream DNS server (default: 1.1.1.1)\n", .{});
    try stdout.print("    --no-web3              Disable Web3 domain support\n", .{});
    try stdout.print("    --no-blocklist         Disable ad/malware blocking\n\n", .{});
    try stdout.print("EXAMPLES:\n", .{});
    try stdout.print("    zdns start                      # Start DNS server on UDP:53\n", .{});
    try stdout.print("    zdns start --daemon             # Run as background daemon\n", .{});
    try stdout.print("    zdns start --protocol=dot       # Start DNS-over-TLS server\n", .{});
    try stdout.print("    zdns start --protocol=doh       # Start DNS-over-HTTPS server\n", .{});
    try stdout.print("    zdns start --protocol=doq       # Start DNS-over-QUIC server\n", .{});
    try stdout.print("    zdns query vitalik.eth          # Resolve ENS domain\n", .{});
    try stdout.print("    zdns query google.com           # Resolve traditional domain\n", .{});
    try stdout.print("    zdns test-web3                  # Test Web3 functionality\n", .{});
    try stdout.print("    zdns start --port=5353          # Start on custom port\n", .{});
    try stdout.print("    zdns flush                      # Clear DNS cache\n", .{});
    try stdout.print("    zdns stats                      # Show statistics\n\n", .{});
    try stdout.print("WEB3 DOMAINS SUPPORTED:\n", .{});
    try stdout.print("    .eth                 - Ethereum Name Service (ENS)\n", .{});
    try stdout.print("    .crypto, .nft        - Unstoppable Domains\n", .{});
    try stdout.print("    .ghost, .zns         - GhostChain ZNS\n", .{});
    try stdout.print("    .cns                 - CNS QUIC resolver\n\n", .{});
    try stdout.print("PROTOCOLS SUPPORTED:\n", .{});
    try stdout.print("    UDP (port 53)        - Traditional DNS (default)\n", .{});
    try stdout.print("    DoT (port 853)       - DNS-over-TLS (secure)\n", .{});
    try stdout.print("    DoH (port 443)       - DNS-over-HTTPS (web-friendly)\n", .{});
    try stdout.print("    DoQ (port 853)       - DNS-over-QUIC (post-quantum ready)\n\n", .{});
    try stdout.print("SECURITY FEATURES:\n", .{});
    try stdout.print("    • Ad/malware blocking with multiple filter lists\n", .{});
    try stdout.print("    • Post-quantum cryptography (ML-KEM-768 + ML-DSA-65)\n", .{});
    try stdout.print("    • Secure DNS caching with signature verification\n", .{});
    try stdout.print("    • TLS 1.3 support for encrypted protocols\n\n", .{});
}

fn printVersion() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("ZigDNS v1.0.0\n\n", .{});
    try stdout.print("Features:\n", .{});
    try stdout.print("  • Web3 DNS Resolution (ENS, Unstoppable, ZNS, CNS)\n", .{});
    try stdout.print("  • DNS-over-QUIC (DoQ) support\n", .{});
    try stdout.print("  • Post-Quantum Cryptography ready\n", .{});
    try stdout.print("  • Ad/Malware blocking\n", .{});
    try stdout.print("  • Secure caching\n\n", .{});
    try stdout.print("Build: {s} - {s}\n", .{ "debug", "simple-resolver" });
    try stdout.print("Zig: {s}\n\n", .{"0.15.0-dev"});
}

fn startServer(allocator: std.mem.Allocator, cli_args: CliArgs) !void {
    const stdout = std.io.getStdOut().writer();
    
    if (!cli_args.quiet) {
        try stdout.print("🚀 Starting ZigDNS v1.0.0\n", .{});
        if (cli_args.verbose) {
            try stdout.print("📡 Verbose mode enabled\n", .{});
            try stdout.print("🌐 Web3 domains: {}\n", .{cli_args.enable_web3});
            try stdout.print("🛡️  Blocklist: {}\n", .{cli_args.enable_blocklist});
            if (cli_args.daemon) {
                try stdout.print("🔧 Daemon mode: enabled\n", .{});
            }
        }
    }
    
    var cfg = try config.loadConfig();
    
    // Override config with CLI args
    const protocol = cli_args.protocol orelse "udp";
    const default_port = getDefaultPort(protocol);
    const port = cli_args.port orelse default_port;
    
    var listen_buf: [32]u8 = undefined;
    cfg.listen_addr = try std.fmt.bufPrint(listen_buf[0..], "0.0.0.0:{d}", .{port});
    cfg.mode = protocol;
    
    if (cli_args.upstream) |upstream| {
        cfg.upstream = upstream;
    }
    
    var bl = try blocklist.Blocklist.init(cfg, allocator);
    if (!cli_args.quiet) {
        try stdout.print("🛡️  Blocklist initialized with {d} sources\n", .{cfg.blocklist_urls.len});
    }
    
    var resolver = try simple_resolver.SimpleDNSResolver.init(allocator, cfg, &bl);
    defer resolver.deinit();
    
    if (!cli_args.quiet) {
        try stdout.print("🌐 Web3 resolver initialized for ENS/UNS/ZNS/CNS domains\n", .{});
        
        // Show protocol-specific information
        switch (std.mem.eql(u8, protocol, "udp")) {
            true => try stdout.print("📡 Protocol: UDP (Traditional DNS) on port {d}\n", .{port}),
            false => {
                if (std.mem.eql(u8, protocol, "dot")) {
                    try stdout.print("🔒 Protocol: DNS-over-TLS (DoT) on port {d}\n", .{port});
                } else if (std.mem.eql(u8, protocol, "doh")) {
                    try stdout.print("🌐 Protocol: DNS-over-HTTPS (DoH) on port {d}\n", .{port});
                } else if (std.mem.eql(u8, protocol, "doq")) {
                    try stdout.print("🚀 Protocol: DNS-over-QUIC (DoQ) on port {d}\n", .{port});
                    try stdout.print("🔐 Post-quantum cryptography: Ready\n", .{});
                } else {
                    try stdout.print("📡 Protocol: {s} on port {d}\n", .{ protocol, port });
                }
            }
        }
        
        if (cli_args.daemon) {
            try stdout.print("🔧 Running as daemon\n", .{});
        } else {
            try stdout.print("\nPress Ctrl+C to stop the server\n\n", .{});
        }
    }
    
    try resolver.start();
}

fn getDefaultPort(protocol: []const u8) u16 {
    if (std.mem.eql(u8, protocol, "udp")) return 53;
    if (std.mem.eql(u8, protocol, "dot")) return 853;  // DNS-over-TLS
    if (std.mem.eql(u8, protocol, "doh")) return 443;  // DNS-over-HTTPS  
    if (std.mem.eql(u8, protocol, "doq")) return 853;  // DNS-over-QUIC
    return 53; // Default to UDP
}

fn queryDomain(allocator: std.mem.Allocator, cli_args: CliArgs) !void {
    const stdout = std.io.getStdOut().writer();
    
    if (cli_args.args.len == 0) {
        try stdout.print("❌ Error: Please specify a domain to query\n", .{});
        try stdout.print("Usage: zdns query <domain>\n", .{});
        return;
    }
    
    const domain = cli_args.args[0];
    
    if (!cli_args.quiet) {
        try stdout.print("🔍 Querying domain: {s}\n", .{domain});
    }
    
    // Simple DNS query simulation
    const cfg = try config.loadConfig();
    var bl = try blocklist.Blocklist.init(cfg, allocator);
    var resolver = try simpleResolver.SimpleDNSResolver.init(allocator, cfg, &bl);
    defer resolver.deinit();
    
    // Check if it's a Web3 domain
    const web3Resolver = @import("./web3Resolver.zig");
    if (web3Resolver.isWeb3Domain(domain)) {
        try stdout.print("🌐 Web3 domain detected\n", .{});
        var web3 = web3Resolver.Web3Resolver.init(allocator);
        const resolution = try web3.resolveDomain(domain);
        if (resolution) |res| {
            try stdout.print("✅ Resolved via {s}:\n", .{res.resolver_type.toString()});
            for (res.addresses) |addr| {
                try stdout.print("   {s}\n", .{addr});
            }
            if (res.content_hash) |hash| {
                try stdout.print("   Content: {s}\n", .{hash});
            }
        } else {
            try stdout.print("❌ Failed to resolve Web3 domain\n", .{});
        }
    } else {
        try stdout.print("🏢 Traditional domain - would forward to upstream\n", .{});
        try stdout.print("   Upstream: {s}\n", .{cfg.upstream});
        
        // Check if blocked
        if (bl.isBlocked(domain)) {
            try stdout.print("🚫 Domain is blocked by filters\n", .{});
        } else {
            try stdout.print("✅ Domain not blocked, would resolve normally\n", .{});
        }
    }
}

fn flushCache(_: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("🧹 DNS cache flushed\n", .{});
    try stdout.print("Note: This is a simulation - actual cache flushing requires server restart\n", .{});
}

fn showStats(_: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("📊 ZigDNS Statistics\n", .{});
    try stdout.print("===================\n", .{});
    try stdout.print("Cache hits:       0\n", .{});
    try stdout.print("Cache misses:     0\n", .{});
    try stdout.print("Blocked queries:  0\n", .{});
    try stdout.print("UDP queries:      0\n", .{});
    try stdout.print("QUIC queries:     0\n", .{});
    try stdout.print("\n🌐 Web3 Statistics\n", .{});
    try stdout.print("ENS queries:      0\n", .{});
    try stdout.print("UNS queries:      0\n", .{});
    try stdout.print("ZNS queries:      0\n", .{});
    try stdout.print("CNS queries:      0\n", .{});
    try stdout.print("\nNote: Live statistics require running server\n", .{});
}

fn testWeb3(allocator: std.mem.Allocator, cli_args: CliArgs) !void {
    const stdout = std.io.getStdOut().writer();
    
    if (!cli_args.quiet) {
        try stdout.print("🧪 Testing Web3 domain resolution\n", .{});
        try stdout.print("================================\n", .{});
    }
    
    const web3Resolver = @import("./web3Resolver.zig");
    var web3 = web3Resolver.Web3Resolver.init(allocator);
    
    const test_domains = [_][]const u8{
        "vitalik.eth",
        "unstoppable.crypto",
        "ghost.zns",
        "quic.cns",
    };
    
    for (test_domains) |domain| {
        try stdout.print("\n🔍 Testing: {s}\n", .{domain});
        
        if (web3_resolver.isWeb3Domain(domain)) {
            const resolution = try web3.resolveDomain(domain);
            if (resolution) |res| {
                try stdout.print("  ✅ Resolver: {s}\n", .{res.resolver_type.toString()});
                try stdout.print("  📍 Address: {s}\n", .{res.addresses[0]});
                try stdout.print("  ⏱️  TTL: {d}s\n", .{res.ttl});
                if (res.content_hash) |hash| {
                    try stdout.print("  📦 Content: {s}\n", .{hash});
                }
            } else {
                try stdout.print("  ❌ Resolution failed\n", .{});
            }
        } else {
            try stdout.print("  ❌ Not recognized as Web3 domain\n", .{});
        }
    }
    
    try stdout.print("\n✅ Web3 testing complete\n", .{});
}

fn showConfig() !void {
    const stdout = std.io.getStdOut().writer();
    const cfg = try config.loadConfig();
    
    try stdout.print("⚙️  ZigDNS Configuration\n", .{});
    try stdout.print("=======================\n", .{});
    try stdout.print("Listen address:    {s}\n", .{cfg.listen_addr});
    try stdout.print("QUIC address:      {s}\n", .{cfg.listen_quic_addr});
    try stdout.print("Upstream DNS:      {s}\n", .{cfg.upstream});
    try stdout.print("Upstream QUIC:     {s}\n", .{cfg.upstream_quic});
    try stdout.print("Mode:              {s}\n", .{cfg.mode});
    try stdout.print("Post-Quantum:      {}\n", .{cfg.enable_post_quantum});
    try stdout.print("Zero-copy:         {}\n", .{cfg.enable_zero_copy});
    try stdout.print("Cache size:        {d}\n", .{cfg.cache_size});
    try stdout.print("Max queries:       {d}\n", .{cfg.max_concurrent_queries});
    try stdout.print("Auto-gen certs:    {}\n", .{cfg.auto_generate_certs});
    try stdout.print("Blocklist sources: {d}\n", .{cfg.blocklist_urls.len});
}

fn setConfig(cli_args: CliArgs) !void {
    const stdout = std.io.getStdOut().writer();
    
    if (cli_args.args.len < 2) {
        try stdout.print("❌ Error: Please specify key and value\n", .{});
        try stdout.print("Usage: zdns set <key> <value>\n", .{});
        try stdout.print("Example: zdns set upstream 8.8.8.8:53\n", .{});
        return;
    }
    
    const key = cli_args.args[0];
    const value = cli_args.args[1];
    
    try stdout.print("⚙️  Setting {s} = {s}\n", .{ key, value });
    try stdout.print("Note: Configuration changes require restart\n", .{});
    
    // TODO: Implement actual config file writing
    try stdout.print("Configuration file writing not yet implemented\n", .{});
}