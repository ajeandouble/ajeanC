const std = @import("std");
const dbg = @import("debug.zig");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("tokens.zig").Token;
const TokenType = @import("tokens.zig").TokenType;
const Parser = @import("./parser.zig").Parser;

const MAX_STDIN_SIZE = 4096;

fn lexTokens(input_stdin: []u8, allocator: std.mem.Allocator) !std.ArrayList(Token) {
    var lexer = try Lexer.init(input_stdin);

    var tokens = std.ArrayList(Token).init(allocator);
    errdefer tokens.deinit();
    var nextToken = try lexer.nextToken();
    try tokens.append(nextToken);
    while (nextToken.type != TokenType.eof) {
        dbg.print("{}: '{s}' L:{}\n", .{ tokens.getLast().type, tokens.getLast().lexeme, tokens.getLast().line }, @src());
        nextToken = try lexer.nextToken();
        try tokens.append(nextToken);
    }
    dbg.print("{}: '{s}' L:{}\n", .{ tokens.getLast().type, tokens.getLast().lexeme, tokens.getLast().line }, @src());
    return tokens;
}

fn parseTokens(tokens: std.ArrayList(Token), allocator: std.mem.Allocator) !void {
    var parser = try Parser.init(tokens.items, allocator);
    _ = try parser.parse();
}

fn parseArgs(args: [][:0]u8) void {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            dbg.verbose = true;
        }
    }
}

pub fn main() !u8 {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);
    parseArgs(args);

    const stdin = std.io.getStdIn().reader();
    const input_stdin = try stdin.readAllAlloc(allocator, MAX_STDIN_SIZE);
    defer allocator.free(input_stdin);

    const tokens = lexTokens(input_stdin, allocator) catch {
        return 1;
    };
    try parseTokens(tokens, allocator);
    tokens.deinit();

    // try parseTokens(

    return 0;
}
