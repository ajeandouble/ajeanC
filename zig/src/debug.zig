const std = @import("std");
const Token = @import("./tokens.zig").Token;
const Node = @import("./ast_nodes.zig").Node;

pub var verbose: bool = true;

pub fn print(comptime fmt: []const u8, args: anytype, comptime src: std.builtin.SourceLocation) void {
    if (verbose) {
        const filename = std.fs.path.basename(src.file);
        std.debug.print("{s}:{}\t{s}\t" ++ fmt, .{ filename, src.line, src.fn_name } ++ args);
    }
}

pub fn printNodeUnion(object: *const Node, comptime src: std.builtin.SourceLocation) void {
    const info = @typeInfo(@TypeOf(object.*));

    if (info != .@"union") {
        @compileError("Not a tagged union");
    }

    const un = info.@"union";
    if (un.tag_type) |TT| {
        // const tag: TT = @field(object, "tag");
        // _ = tag;
        _ = TT;
        inline for (un.fields) |field| {
            if (std.mem.eql(u8, field.name, @tagName(object.*))) {
                const field_value = @field(object, field.name);
                inline for (@typeInfo(@TypeOf(field_value.*)).@"struct".fields) |fld| {
                    if (std.mem.eql(u8, fld.name, "token")) {
                        const fld_val = @field(field_value, fld.name);
                        if (@TypeOf(fld_val) == Token) {
                            print("{s}\n", .{fld_val.lexeme orelse return}, src);
                        } else {}
                    }
                }
                break;
            }
        }
    } else {
        @compileError("Union has no tag type");
    }
}

pub fn printUnion(comptime T: type, object: T, comptime src: std.builtin.SourceLocation) void {
    const info = @typeInfo(Node);

    if (info != .@"union") {
        @compileError("Not a tagged union");
    }

    const un = info.@"union";
    if (un.tag_type) |TT| {
        // const tag: TT = @field(object, "tag");
        // _ = tag;
        _ = TT;
        inline for (un.fields) |field| {
            if (std.mem.eql(u8, field.name, @tagName(object))) {
                const field_value = @field(object, field.name);
                print("{}\n", field_value, src);
                break;
            }
        }
    } else {
        @compileError("Union has no tag type");
    }
}
