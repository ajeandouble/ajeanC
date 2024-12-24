const std = @import("std");

pub var verbose: bool = false;

pub fn print(comptime fmt: []const u8, args: anytype, comptime src: std.builtin.SourceLocation) void {
    if (verbose) {
        std.debug.print("{s}:{}\t{s}\t" ++ fmt, .{ src.file, src.line, src.fn_name } ++ args);
    }
}
