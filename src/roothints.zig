const std = @import("std");

pub fn updateRootHints(allocator: std.mem.Allocator) !void {
    const url = "https://www.internic.net/domain/named.cache";
    const log = std.io.getStdErr().writer();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var req = try client.open(.GET, url, .{});
    try req.send();

    const body = try req.reader().readAllAlloc(allocator, 64 * 1024); // 64KB max
    defer allocator.free(body);

    var file = try std.fs.cwd().createFile("root.hints", .{
        .truncate = true,
        .read = true,
        .write = true,
    });
    defer file.close();

    _ = try file.writeAll(body);

    try log.print("Downloaded root hints ({} bytes) to root.hints\n", .{body.len});
}
