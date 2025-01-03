const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;
const reserved = @import("./lex_constants.zig").reserved;
const op_math = @import("./lex_constants.zig").math;
const op_cmp = @import("./lex_constants.zig").cmp;
const op_assign = @import("./lex_constants.zig").assign;
const delimeters = @import("./lex_constants.zig").delimeters;
const separators = @import("./lex_constants.zig").separators;
const Error = error{ NullSource, NullTokens, BadToken, OutOfBounds, UnterminatedString };

const reserved_kws = std.StaticStringMap(TokenType).initComptime(.{
    .{ reserved._function, TokenType.function_kw },
    .{ reserved._return, TokenType.return_kw },
    .{ reserved._if, TokenType.if_kw },
    .{ reserved._else, TokenType.else_kw },
    .{ reserved._while, TokenType.while_kw },
    .{ reserved._for, TokenType.for_kw },
    .{ reserved._break, TokenType.break_kw },
    .{ reserved._continue, TokenType.continue_kw },
});

const single_chr_toks = std.StaticStringMap(TokenType).initComptime(.{
    .{ op_math.plus, TokenType.plus },
    .{ op_math.minus, TokenType.minus },
    .{ op_math.mul, TokenType.mul },
    .{ op_math.div, TokenType.div },
    .{ op_math.mod, TokenType.mod },
    .{ op_cmp.lt, TokenType.lt },
    .{ op_assign.assign, TokenType.assign },
    .{ op_cmp.gt, TokenType.gt },
    .{ delimeters.lparen, TokenType.lparen },
    .{ delimeters.rparen, TokenType.rparen },
    .{ delimeters.lbrace, TokenType.lbrace },
    .{ delimeters.rbrace, TokenType.rbrace },
    .{ delimeters.lbrack, TokenType.lbrack },
    .{ delimeters.rbrack, TokenType.rbrack },
    .{ separators.comma, TokenType.comma },
    .{ separators.semi, TokenType.semi },
    .{ "\n", TokenType.eol },
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
    source: ?([]const u8) = undefined,
    pos: usize = 0,
    line: usize = 0,
    tokens: ?std.ArrayList(Token),

    pub fn init(buffer: []const u8, allocator: std.mem.Allocator) !Self {
        const tokens = std.ArrayList(Token).init(allocator);
        const lexer = Self{ .allocator = allocator, .source = buffer, .tokens = tokens };
        return lexer;
    }

    pub fn deinit(self: *Self) void {
        for (self.tokens.?.items) |*tok| {
            tok.deinit();
            tok.lexeme = null;
        }
        self.tokens.?.deinit();
        self.tokens = null;
    }

    pub fn tokenize(self: *Self) !void {
        if (self.tokens) |*tokens| {
            var next_tok = try self.nextToken();
            try tokens.append(next_tok);
            while (next_tok.type != TokenType.eof) {
                dbg.print("{}: '{s}' L:{}\n", .{ next_tok.type, next_tok.lexeme.?, next_tok.line }, @src());
                next_tok = try self.nextToken();
                try tokens.*.append(next_tok);
            }
        } else {
            return Error.NullTokens;
        }
    }

    pub fn getTokens(self: *const Self) !std.ArrayList(Token) {
        return self.tokens orelse Error.NullTokens;
    }

    fn nextToken(self: *Self) !Token {
        self.skipWhitespace() catch {
            return Token.init(TokenType.eof, "", self.line, self.allocator);
        };

        if (self.isAtEnd()) {
            return Token.init(TokenType.eof, "", self.line, self.allocator);
        }

        for (reserved_kws.keys()) |kw| {
            if (std.mem.eql(u8, self.lookAhead(kw.len), kw)) {
                const following_chr = self.peek(kw.len);
                if (following_chr != 0x0 and std.ascii.isAlphanumeric(following_chr)) {
                    continue;
                }
                try self.advance(kw.len);
                const tokType = reserved_kws.get(kw) orelse unreachable;
                return Token.init(tokType, kw, self.line, self.allocator);
            }
        }

        for (mult_chr_toks.keys()) |kw| {
            if (std.mem.eql(u8, self.lookAhead(kw.len), kw)) {
                try self.advance(kw.len);
                const tokType = mult_chr_toks.get(kw) orelse unreachable;
                return Token.init(tokType, kw, self.line, self.allocator);
            }
        }

        if (self.peek(0) == '"') {
            return try self.string();
        }

        for (single_chr_toks.keys()) |kw| {
            const single_chr = kw[0];
            if (self.peek(0) == single_chr) {
                try self.advance(1);
                const tokType = single_chr_toks.get(kw) orelse unreachable;
                return Token.init(tokType, kw, self.line, self.allocator);
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

    // Helper functions
    fn string(self: *Self) !Token {
        const start = self.pos;
        try self.advance(1);
        while (self.peek(0) != '"' and self.peek(0) != 0x00) {
            try self.advance(1);
        }
        if (self.pos == self.source.?.len) {
            return Error.UnterminatedString;
        }
        try self.advance(1);
        return Token.init(TokenType.string, self.source.?[start..self.pos], self.line, self.allocator);
    }

    fn num(self: *Self) !Token {
        const start = self.pos;
        var n: i28 = 0;
        while (std.ascii.isDigit(self.peek(0))) {
            n *= 10;
            n += @intCast(self.peek(0));
            try self.advance(1);
        }
        return Token.init(TokenType.integer, self.source.?[start..self.pos], self.line, self.allocator);
    }

    fn id(self: *Self) !Token {
        const start = self.pos;
        while (std.ascii.isAlphanumeric(self.peek(0))) {
            try self.advance(1);
        }
        return Token.init(TokenType.id, self.source.?[start..self.pos], self.line, self.allocator);
    }

    // Utils functions
    inline fn peek(self: *const Self, offset: ?usize) u8 {
        const offs = offset orelse 0;
        return if (self.pos + offs < self.source.?.len) self.source.?[self.pos + offs] else 0x00;
    }

    inline fn lookAhead(self: *const Self, len: usize) []const u8 {
        if (self.pos + len >= self.source.?.len) {
            return "";
        }
        return self.source.?[self.pos .. self.pos + len];
    }

    inline fn advance(self: *Self, offset: ?usize) !void {
        const offs = offset orelse 1;
        if (self.pos + offs <= self.source.?.len) {
            self.pos += offs;
        } else {
            return Error.OutOfBounds;
        }
    }

    inline fn isAtEnd(self: *const Self) bool {
        return self.pos >= (self.source orelse unreachable).len;
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

fn setupLextStringTest(s: []const u8) anyerror!Lexer {
    const allocator = std.testing.allocator;
    var lexer = try Lexer.init(s, allocator);
    try lexer.tokenize();
    return lexer;
}

fn teardownLexStringTest(lexer: *Lexer) void {
    lexer.deinit();
}

test "lexer init and cleanup" {
    var lexer = try setupLextStringTest("function return if else while for break continue ");
    try lexer.tokenize();
    teardownLexStringTest(&lexer);
}

test "lexer reserved keywords" {
    var lexer = try setupLextStringTest("function return if else while for break continue ");
    try lexer.tokenize();
    const tokens = try lexer.getTokens();
    // function
    const tok_0 = try tokens.items[0].getToken();
    const tok_0_lexeme = try tokens.items[0].getLexeme();
    try std.testing.expect(std.mem.eql(u8, tok_0_lexeme, reserved._function));
    try std.testing.expect(tok_0.type == TokenType.function_kw);
    try std.testing.expect(tok_0.line == 0);

    // return
    const tok_1 = try tokens.items[1].getToken();
    const tok_1_lexeme = try tok_1.getLexeme();
    try std.testing.expect(std.mem.eql(u8, tok_1_lexeme, reserved._return));
    try std.testing.expect(tok_1.type == TokenType.return_kw);
    try std.testing.expect(tok_1.line == 0);

    // if
    const tok_2 = try tokens.items[2].getToken();
    const tok_2_lexeme = try tok_2.getLexeme();
    try std.testing.expect(std.mem.eql(u8, tok_2_lexeme, reserved._if));
    try std.testing.expect(tok_2.type == TokenType.if_kw);
    try std.testing.expect(tok_2.line == 0);

    // // else
    const tok_3 = try tokens.items[3].getToken();
    const tok_3_lexeme = try tok_3.getLexeme();
    try std.testing.expect(std.mem.eql(u8, tok_3_lexeme, reserved._else));
    try std.testing.expect(tok_3.type == TokenType.else_kw);
    try std.testing.expect(tok_3.line == 0);

    // while
    const tok_4 = try tokens.items[4].getToken();
    const tok_4_lexeme = try tok_4.getLexeme();
    try std.testing.expect(std.mem.eql(u8, tok_4_lexeme, reserved._while));
    try std.testing.expect(tok_4.type == TokenType.while_kw);
    try std.testing.expect(tok_4.line == 0);

    // for
    const tok_5 = try tokens.items[5].getToken();
    const tok_5_lexeme = try tok_5.getLexeme();
    try std.testing.expect(std.mem.eql(u8, tok_5_lexeme, reserved._for));
    try std.testing.expect(tok_5.type == TokenType.for_kw);
    try std.testing.expect(tok_5.line == 0);

    // break
    const tok_6 = try tokens.items[6].getToken();
    const tok_6_lexeme = try tok_6.getLexeme();
    try std.testing.expect(std.mem.eql(u8, tok_6_lexeme, reserved._break));
    try std.testing.expect(tok_6.type == TokenType.break_kw);
    try std.testing.expect(tok_6.line == 0);

    // continue
    const tok_7 = try tokens.items[7].getToken();
    const tok_7_lexeme = try tok_7.getLexeme();
    try std.testing.expect(std.mem.eql(u8, tok_7_lexeme, reserved._continue));
    try std.testing.expect(tok_7.type == TokenType.continue_kw);
    try std.testing.expect(tok_7.line == 0);

    teardownLexStringTest(&lexer);
}

test "lexer operators - assignments and math" {
    var lexer = try setupLextStringTest("= + - * / % ");
    try lexer.tokenize();
    const tokens = try lexer.getTokens();

    try std.testing.expect(tokens.items[0].type == TokenType.assign);
    try std.testing.expect(tokens.items[1].type == TokenType.plus);
    try std.testing.expect(tokens.items[2].type == TokenType.minus);
    try std.testing.expect(tokens.items[3].type == TokenType.mul);
    try std.testing.expect(tokens.items[4].type == TokenType.div);
    try std.testing.expect(tokens.items[5].type == TokenType.mod);

    teardownLexStringTest(&lexer);
}

test "lexer delimiters" {
    var lexer = try setupLextStringTest("( )\n{}\n[] ,;");
    try lexer.tokenize();
    const tokens = try lexer.getTokens();

    try std.testing.expect(tokens.items[0].type == TokenType.lparen);
    try std.testing.expect(tokens.items[1].type == TokenType.rparen);
    try std.testing.expect(tokens.items[2].type == TokenType.lbrace);
    try std.testing.expect(tokens.items[3].type == TokenType.rbrace);
    try std.testing.expect(tokens.items[4].type == TokenType.lbrack);
    try std.testing.expect(tokens.items[5].type == TokenType.rbrack);
    try std.testing.expect(tokens.items[6].type == TokenType.comma);
    try std.testing.expect(tokens.items[7].type == TokenType.semi);

    teardownLexStringTest(&lexer);
}

test "lexer comparisons" {
    var lexer = try setupLextStringTest("< <= == >= >");
    try lexer.tokenize();
    const tokens = try lexer.getTokens();

    try std.testing.expect(tokens.items[0].type == TokenType.lt);
    try std.testing.expect(tokens.items[1].type == TokenType.le);
    try std.testing.expect(tokens.items[2].type == TokenType.eq);
    try std.testing.expect(tokens.items[3].type == TokenType.ge);
    try std.testing.expect(tokens.items[4].type == TokenType.gt);

    teardownLexStringTest(&lexer);
}

test "lexer values" {
    var lexer = try setupLextStringTest("\"hello\" 42 myVariable");
    try lexer.tokenize();
    const tokens = try lexer.getTokens();

    // String token
    const tok_str = try tokens.items[0].getToken();
    const tok_str_lexeme = try tok_str.getLexeme();
    try std.testing.expect(tok_str.type == TokenType.string);
    try std.testing.expectEqualStrings(tok_str_lexeme, "\"hello\"");

    // Integer token
    const tok_int = try tokens.items[1].getToken();
    const tok_int_lexeme = try tok_int.getLexeme();
    try std.testing.expect(tok_int.type == TokenType.integer);
    try std.testing.expect(std.mem.eql(u8, tok_int_lexeme, "42"));

    // Identifier token
    const tok_id = try tokens.items[2].getToken();
    const tok_id_lexeme = try tok_id.getLexeme();
    try std.testing.expect(tok_id.type == TokenType.id);
    try std.testing.expect(std.mem.eql(u8, tok_id_lexeme, "myVariable"));

    teardownLexStringTest(&lexer);
}

test "lexer line counting" {
    var lexer = try setupLextStringTest("0\n1\n2\n3");
    try lexer.tokenize();
    defer teardownLexStringTest(&lexer);

    const tokens = try lexer.getTokens();

    try std.testing.expect(tokens.items[0].line == 0);
    try std.testing.expect(tokens.items[1].line == 1);
    try std.testing.expect(tokens.items[2].line == 2);
    try std.testing.expect(tokens.items[3].line == 3);
}

test "lexer mixed expression" {
    var lexer = try setupLextStringTest("function foobar(foo, bar) { return foo + bar; }");
    try lexer.tokenize();
    defer teardownLexStringTest(&lexer);

    const tokens = try lexer.getTokens();

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
}

test "lexer error cases" {
    const allocator = std.testing.allocator;

    // Test invalid character
    var lexer_invalid_1 = try Lexer.init("@", allocator);
    errdefer allocator.free(lexer_invalid_1.source.?);
    try std.testing.expectError(Error.BadToken, lexer_invalid_1.nextToken());

    // Test unterminated string
    var lexer_invalid_2 = try Lexer.init("\"hello", allocator);
    errdefer allocator.free(lexer_invalid_2.source.?);
    try std.testing.expectError(Error.UnterminatedString, lexer_invalid_2.nextToken());
}
