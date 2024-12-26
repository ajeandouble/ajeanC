const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;

const Error = error{ BadToken, OutOfBounds, UnterminatedString };

const reserved_kws = std.StaticStringMap(TokenType).initComptime(.{
    .{ "function", TokenType.function_kw },
    .{ "return", TokenType.return_kw },
    .{ "if", TokenType.if_kw },
    .{ "else", TokenType.else_kw },
    .{ "while", TokenType.while_kw },
    .{ "for", TokenType.for_kw },
    .{ "break", TokenType.break_kw },
    .{ "continue", TokenType.continue_kw },
});

const single_chr_toks = std.StaticStringMap(TokenType).initComptime(.{
    .{ "+", TokenType.plus },
    .{ "-", TokenType.minus },
    .{ "*", TokenType.mul },
    .{ "/", TokenType.div },
    .{ "%", TokenType.mod },
    .{ "<", TokenType.lt },
    .{ "=", TokenType.assign },
    .{ ">", TokenType.gt },
    .{ "(", TokenType.lparen },
    .{ ")", TokenType.rparen },
    .{ "{", TokenType.lbrace },
    .{ "}", TokenType.rbrace },
    .{ ",", TokenType.comma },
    .{ ";", TokenType.semi },
    .{ "\n", TokenType.eol },
    .{ "[", TokenType.lbrack },
    .{ "]", TokenType.rbrack },
});

const mult_chr_toks = std.StaticStringMap(TokenType).initComptime(.{
    .{ "==", TokenType.eq },
    .{ "<=", TokenType.le },
    .{ ">=", TokenType.ge },
});

const whitespaces_no_nl = std.StaticStringMap(undefined).initComptime(.{
    .{" "},
    .{"\t"},
    .{"\r"},
});

pub const Lexer: type = struct {
    const Self = @This();
    allocator: std.mem.Allocator = undefined,
    source: []u8 = undefined,
    pos: usize = 0,
    line: usize = 0,

    // TODO: pass allocator
    pub fn init(buffer: []const u8, allocator: std.mem.Allocator) !Self {
        const lexer = Self{
            .allocator = allocator,
            .source = try allocator.alloc(u8, buffer.len),
        };
        @memcpy(lexer.source, buffer);
        return lexer;
    }

    pub fn nextToken(self: *Self) !Token {
        self.skipWhitespace() catch {
            const lexeme = try self.allocator.dupe(u8, "");
            return Token{ .type = TokenType.eof, .lexeme = lexeme, .line = self.line };
        };

        if (self.isAtEnd()) {
            const lexeme = try self.allocator.dupe(u8, "");

            return Token{
                .type = TokenType.eof,
                .lexeme = lexeme,
                .line = self.line,
            };
        }

        for (reserved_kws.keys()) |kw| {
            if (std.mem.eql(u8, self.lookAhead(kw.len), kw)) {
                const following_chr = self.peek(kw.len);
                if (following_chr != 0x0 and std.ascii.isAlphanumeric(following_chr)) {
                    continue;
                }
                try self.advance(kw.len);
                const tokType = reserved_kws.get(kw) orelse unreachable;
                const lexeme = try self.allocator.dupe(u8, kw);
                return Token{ .type = tokType, .lexeme = lexeme, .line = self.line };
            }
        }

        for (mult_chr_toks.keys()) |kw| {
            if (std.mem.eql(u8, self.lookAhead(kw.len), kw)) {
                const tokType = mult_chr_toks.get(kw) orelse unreachable;
                try self.advance(kw.len);
                const lexeme = try self.allocator.dupe(u8, kw);
                return Token{ .type = tokType, .lexeme = lexeme, .line = self.line };
            }
        }

        if (self.peek(0) == '"') {
            return try self.string();
        }

        for (single_chr_toks.keys()) |kw| {
            const single_chr = kw[0];
            if (self.peek(0) == single_chr) {
                const tokType = single_chr_toks.get(kw) orelse unreachable;
                try self.advance(1);
                const lexeme = try self.allocator.dupe(u8, kw);
                return Token{ .type = tokType, .lexeme = lexeme, .line = self.line };
            }
        }

        if (std.ascii.isDigit(self.peek(0))) {
            return try self.num();
        }

        if (std.ascii.isAlphabetic(self.peek(0))) {
            return try self.id();
        }

        try self.advance(1);
        return Error.BadToken;
    }

    fn string(self: *Self) !Token {
        const start = self.pos;
        try self.advance(1);
        while (self.peek(0) != '"' and self.peek(0) != 0x00) {
            try self.advance(1);
        }
        if (self.pos == self.source.len) {
            return Error.UnterminatedString;
        }
        try self.advance(1);
        return Token{ .type = TokenType.string, .lexeme = try self.allocator.dupe(u8, self.source[start..self.pos]), .line = self.line };
    }

    fn num(self: *Self) !Token {
        const start = self.pos;
        var n: i28 = 0;
        while (std.ascii.isDigit(self.peek(0))) {
            n *= 10;
            n += @intCast(self.peek(0));
            try self.advance(1);
        }
        return Token{ .type = TokenType.integer, .lexeme = try self.allocator.dupe(u8, self.source[start..self.pos]), .line = self.line };
    }

    fn id(self: *Self) !Token {
        const start = self.pos;
        while (std.ascii.isAlphanumeric(self.peek(0))) {
            try self.advance(1);
        }
        return Token{ .type = TokenType.id, .lexeme = try self.allocator.dupe(u8, self.source[start..self.pos]), .line = self.line };
    }

    // Utils functions
    inline fn peek(self: *const Self, offset: ?usize) u8 {
        const offs = offset orelse 0;
        return if (self.pos + offs < self.source.len) self.source[self.pos + offs] else 0x00;
    }

    inline fn lookAhead(self: *const Self, len: usize) []u8 {
        if (self.pos + len >= self.source.len) {
            return "";
        }
        return self.source[self.pos .. self.pos + len];
    }

    inline fn advance(self: *Self, offset: ?usize) !void {
        const offs = offset orelse 1;
        if (self.pos + offs <= self.source.len) {
            self.pos += offs;
        } else {
            return Error.OutOfBounds;
        }
    }

    inline fn isAtEnd(self: *const Self) bool {
        return self.pos >= self.source.len;
    }

    fn skipWhitespace(self: *Self) Error!void {
        while (!self.isAtEnd()) {
            switch (self.peek(0)) {
                ' ', '\r', '\t' => try self.advance(1),
                '\n' => {
                    self.line += 1;
                    try self.advance(1);
                },
                else => break,
            }
        } else {
            return Error.OutOfBounds;
        }
    }
};

// Testing
const expect = std.testing.expect;

const SetupRet = std.meta.Tuple(&.{ std.ArrayList(Token), Lexer });

fn setupLextStringTest(s: []const u8) !SetupRet {
    const allocator = std.testing.allocator;
    var lexer = try Lexer.init(s, allocator);

    var tokens = std.ArrayList(Token).init(allocator);
    errdefer tokens.deinit();
    var nextToken = try lexer.nextToken();
    try tokens.append(nextToken);
    while (nextToken.type != TokenType.eof) {
        nextToken = try lexer.nextToken();
        try tokens.append(nextToken);
    }
    return .{ tokens, lexer };
}

fn teardownLexStringTest(tokens: std.ArrayList(Token), lexer: Lexer) void {
    for (tokens.items) |tok| {
        lexer.allocator.free(tok.lexeme);
    }
    tokens.deinit();
    std.testing.allocator.free(lexer.source);
}

test "lexer reserved keywords" {
    const ret = try setupLextStringTest("function return if else while for break continue ");
    const tokens = ret[0];
    const lexer = ret[1];

    // function
    try std.testing.expect(std.mem.eql(u8, tokens.items[0].lexeme, "function"));
    try std.testing.expect(tokens.items[0].type == TokenType.function_kw);
    try std.testing.expect(tokens.items[0].line == 0);

    // return
    try std.testing.expect(std.mem.eql(u8, tokens.items[1].lexeme, "return"));
    try std.testing.expect(tokens.items[1].type == TokenType.return_kw);
    try std.testing.expect(tokens.items[1].line == 0);

    // if
    try std.testing.expect(std.mem.eql(u8, tokens.items[2].lexeme, "if"));
    try std.testing.expect(tokens.items[2].type == TokenType.if_kw);
    try std.testing.expect(tokens.items[2].line == 0);

    // else
    try std.testing.expect(std.mem.eql(u8, tokens.items[3].lexeme, "else"));
    try std.testing.expect(tokens.items[3].type == TokenType.else_kw);
    try std.testing.expect(tokens.items[3].line == 0);

    // while
    try std.testing.expect(std.mem.eql(u8, tokens.items[4].lexeme, "while"));
    try std.testing.expect(tokens.items[4].type == TokenType.while_kw);
    try std.testing.expect(tokens.items[4].line == 0);

    // for
    try std.testing.expect(std.mem.eql(u8, tokens.items[5].lexeme, "for"));
    try std.testing.expect(tokens.items[5].type == TokenType.for_kw);
    try std.testing.expect(tokens.items[5].line == 0);

    // break
    try std.testing.expect(std.mem.eql(u8, tokens.items[6].lexeme, "break"));
    try std.testing.expect(tokens.items[6].type == TokenType.break_kw);
    try std.testing.expect(tokens.items[6].line == 0);

    // continue
    try std.testing.expect(std.mem.eql(u8, tokens.items[7].lexeme, "continue"));
    try std.testing.expect(tokens.items[7].type == TokenType.continue_kw);
    try std.testing.expect(tokens.items[7].line == 0);

    teardownLexStringTest(tokens, lexer);
}

test "lexer operators - assignments and math" {
    const ret = try setupLextStringTest("= + - * / % ");
    const tokens = ret[0];
    const lexer = ret[1];

    try std.testing.expect(tokens.items[0].type == TokenType.assign);
    try std.testing.expect(tokens.items[1].type == TokenType.plus);
    try std.testing.expect(tokens.items[2].type == TokenType.minus);
    try std.testing.expect(tokens.items[3].type == TokenType.mul);
    try std.testing.expect(tokens.items[4].type == TokenType.div);
    try std.testing.expect(tokens.items[5].type == TokenType.mod);

    teardownLexStringTest(tokens, lexer);
}

test "lexer delimiters" {
    const ret = try setupLextStringTest("( ) { } [ ] , ;");
    const tokens = ret[0];
    const lexer = ret[1];

    try std.testing.expect(tokens.items[0].type == TokenType.lparen);
    try std.testing.expect(tokens.items[1].type == TokenType.rparen);
    try std.testing.expect(tokens.items[2].type == TokenType.lbrace);
    try std.testing.expect(tokens.items[3].type == TokenType.rbrace);
    try std.testing.expect(tokens.items[4].type == TokenType.lbrack);
    try std.testing.expect(tokens.items[5].type == TokenType.rbrack);
    try std.testing.expect(tokens.items[6].type == TokenType.comma);
    try std.testing.expect(tokens.items[7].type == TokenType.semi);

    teardownLexStringTest(tokens, lexer);
}

test "lexer comparisons" {
    const ret = try setupLextStringTest("<= < == >= >");
    const tokens = ret[0];
    const lexer = ret[1];

    try std.testing.expect(tokens.items[0].type == TokenType.le);
    try std.testing.expect(tokens.items[1].type == TokenType.lt);
    try std.testing.expect(tokens.items[2].type == TokenType.eq);
    try std.testing.expect(tokens.items[3].type == TokenType.ge);
    try std.testing.expect(tokens.items[4].type == TokenType.gt);

    teardownLexStringTest(tokens, lexer);
}

test "lexer values" {
    const ret = try setupLextStringTest("\"hello\" 42 myVariable");
    const tokens = ret[0];
    const lexer = ret[1];

    // String token
    try std.testing.expect(tokens.items[0].type == TokenType.string);
    try std.testing.expectEqualStrings(tokens.items[0].lexeme, "\"hello\"");

    // Integer token
    try std.testing.expect(tokens.items[1].type == TokenType.integer);
    try std.testing.expect(std.mem.eql(u8, tokens.items[1].lexeme, "42"));

    // Identifier token
    try std.testing.expect(tokens.items[2].type == TokenType.id);
    try std.testing.expect(std.mem.eql(u8, tokens.items[2].lexeme, "myVariable"));

    teardownLexStringTest(tokens, lexer);
}

test "lexer line counting" {
    const ret = try setupLextStringTest("a\nb\nc\n");
    const tokens = ret[0];
    const lexer = ret[1];

    try std.testing.expect(tokens.items[0].line == 0);
    try std.testing.expect(tokens.items[1].line == 1);
    try std.testing.expect(tokens.items[2].line == 2);
    try std.testing.expect(tokens.items[3].line == 3);

    teardownLexStringTest(tokens, lexer);
}

test "lexer mixed expression" {
    const ret = try setupLextStringTest("function add(a, b) { return a + b; }");
    const tokens = ret[0];
    const lexer = ret[1];

    try std.testing.expect(tokens.items[0].type == TokenType.function_kw);
    try std.testing.expect(tokens.items[1].type == TokenType.id);
    try std.testing.expect(tokens.items[2].type == TokenType.lparen);
    try std.testing.expect(tokens.items[3].type == TokenType.id);
    try std.testing.expect(tokens.items[4].type == TokenType.comma);
    try std.testing.expect(tokens.items[5].type == TokenType.id);
    try std.testing.expect(tokens.items[6].type == TokenType.rparen);
    try std.testing.expect(tokens.items[7].type == TokenType.lbrace);
    try std.testing.expect(tokens.items[8].type == TokenType.return_kw);
    try std.testing.expect(tokens.items[9].type == TokenType.id);
    try std.testing.expect(tokens.items[10].type == TokenType.plus);
    try std.testing.expect(tokens.items[11].type == TokenType.id);
    try std.testing.expect(tokens.items[12].type == TokenType.semi);
    try std.testing.expect(tokens.items[13].type == TokenType.rbrace);

    teardownLexStringTest(tokens, lexer);
}

test "lexer error cases" {
    // Test invalid character
    const allocator = std.testing.allocator;
    var lexer_invalid_1 = try Lexer.init("@", allocator);
    defer allocator.free(lexer_invalid_1.source);
    try std.testing.expectError(Error.BadToken, lexer_invalid_1.nextToken());

    var lexer_invalid_2 = try Lexer.init("\"hello", allocator);
    defer allocator.free(lexer_invalid_2.source);
    try std.testing.expectError(Error.UnterminatedString, lexer_invalid_2.nextToken());
}
