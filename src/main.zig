const std = @import("std");
const xml = @import("xml.zig");
const zig_xmpp_client = @import("zig_xmpp_client");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    try zig_xmpp_client.bufferedPrint();
}

