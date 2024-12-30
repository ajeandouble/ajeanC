const std = @import("std");

pub var verbose: bool = true;

pub fn print(comptime fmt: []const u8, args: anytype, comptime src: std.builtin.SourceLocation) void {
    if (verbose) {
        const filename = std.fs.path.basename(src.file);
        std.debug.print("{s}:{}\t{s}\t" ++ fmt, .{ filename, src.line, src.fn_name } ++ args);
    }
}
