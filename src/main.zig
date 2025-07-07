const std = @import("std");
const config = @import("./config.zig");
const blocklist = @import("./blocklist.zig");
const enhanced_resolver = @import("./enhanced_resolver.zig");
const simple_resolver = @import("./simple_resolver.zig");
const cli = @import("./cli.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    // Convert args to proper format
    var converted_args = try allocator.alloc([]const u8, args.len);
    defer allocator.free(converted_args);
    for (args, 0..) |arg, i| {
        converted_args[i] = arg;
    }
    
    const cli_args = cli.parseArgs(allocator, converted_args) catch |err| {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("❌ Error parsing arguments: {}\n", .{err});
        try stderr.print("Use 'zdns help' for usage information\n", .{});
        std.process.exit(1);
    };
    
    // If no command specified, default to start
    const final_args = if (converted_args.len == 1) blk: {
        var default_args = cli_args;
        default_args.command = .start;
        break :blk default_args;
    } else cli_args;
    
    // Run the CLI command
    cli.runCli(allocator, final_args) catch |err| {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("❌ Error: {}\n", .{err});
        std.process.exit(1);
    };
}
