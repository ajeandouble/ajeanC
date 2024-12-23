const std = @import("std");
const dbg = @import("debug.zig");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("tokens.zig").Token;
const TokenType = @import("tokens.zig").TokenType;

const MAX_STDIN_SIZE = 4096;

fn lex_tokens(input_stdin: []u8) !void {
    var lexer = try Lexer.init(input_stdin);

    var tok = try lexer.nextToken();
    while (tok.type != TokenType.eof) {
        dbg.print("{}: '{s}' L:{}\n", .{ tok.type, tok.lexeme, tok.line });
        tok = try lexer.nextToken();
    }
    dbg.print("{}: '{s}' L:{}\n", .{ tok.type, tok.lexeme, tok.line });
}

fn parseArgs(args: [][:0]u8) void {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            dbg.verbose = true;
        }
    }
}

pub fn main() !u8 {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);
    parseArgs(args);

    const stdin = std.io.getStdIn().reader();
    const allocator = std.heap.page_allocator;
    const input_stdin = try stdin.readAllAlloc(allocator, MAX_STDIN_SIZE);
    defer allocator.free(input_stdin);

    try lex_tokens(input_stdin);
    return 0;
}
