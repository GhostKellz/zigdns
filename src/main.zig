const std = @import("std");
const config = @import("./config.zig");
const blocklist = @import("./blocklist.zig");
const resolver = @import("./resolver.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("ZigDNS - Blazing Fast DNS Resolver (Zig)\n", .{});

    const allocator = std.heap.page_allocator;

    const cfg = try config.loadConfig();
    var bl = try blocklist.Blocklist.init(cfg, allocator);

    var res = try resolver.Resolver.init(allocator, cfg, &bl);

    try res.start();
}
