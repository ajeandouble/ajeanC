const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;

const Error = error{OutOfBounds};

const reserved_kws = std.StaticStringMap(TokenType).initComptime(.{
    .{ "function", TokenType.function_kw },
    .{ "return", TokenType.return_kw },
    .{ "if", TokenType.return_kw },
    .{ "else", TokenType.return_kw },
});

const single_chr_toks = std.StaticStringMap(TokenType).initComptime(.{
    .{ "+", TokenType.plus },
    .{ "-", TokenType.minus },
    .{ "*", TokenType.mul },
    .{ "/", TokenType.div },
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

// NOTE: What about hashsets?

pub const Lexer: type = struct {
    source: []u8 = undefined,
    pos: usize = 0,
    line: usize = 0,

    pub fn init(buffer: []u8) !Lexer {
        const allocator = std.heap.page_allocator;
        const lexer = Lexer{
            .source = try allocator.alloc(u8, buffer.len),
        };
        @memcpy(lexer.source, buffer);
        return lexer;
    }

    pub fn nextToken(self: *Lexer) !Token {
        dbg.print("{}:'{c}'\t", .{ self.pos, self.source[self.pos] });
        self.skipWhitespace() catch {
            return Token{ .type = TokenType.eof, .lexeme = "", .line = self.line };
        };

        if (self.isAtEnd()) {
            return Token{
                .type = TokenType.eof,
                .lexeme = "",
                .line = self.line,
            };
        }

        for (reserved_kws.keys()) |kw| {
            if (std.mem.eql(u8, self.look_ahead(kw.len), kw)) {
                const following_chr = self.peek(kw.len);
                if (following_chr != 0x0 and std.ascii.isAlphanumeric(following_chr)) {
                    continue;
                }
                try self.advance(kw.len);
                const tokType = reserved_kws.get(kw) orelse unreachable;
                return Token{ .type = tokType, .lexeme = kw, .line = self.line };
            }
        }

        for (mult_chr_toks.keys()) |kw| {
            if (std.mem.eql(u8, self.look_ahead(kw.len), kw)) {
                const tokType = reserved_kws.get(kw) orelse unreachable;
                try self.advance(kw.len);
                return Token{ .type = tokType, .lexeme = kw, .line = self.line };
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
                return Token{ .type = tokType, .lexeme = kw, .line = self.line };
            }
        }

        if (std.ascii.isDigit(self.peek(0))) {
            return try self.num();
        }

        if (std.ascii.isAlphabetic(self.peek(0))) {
            return try self.id();
        }

        try self.advance(1);
        return Token{ .type = TokenType.dummy, .lexeme = "", .line = 0 };
    }

    fn string(self: *Lexer) !Token {
        const start = self.pos;
        try self.advance(1);
        while (self.peek(0) != '"' and self.peek(0) != 0x00) {
            try self.advance(1);
        }
        try self.advance(1);
        return Token{ .type = TokenType.string, .lexeme = self.source[start..self.pos], .line = self.line };
    }

    fn num(self: *Lexer) !Token {
        const start = self.pos;
        var n: i28 = 0;
        while (std.ascii.isDigit(self.peek(0))) {
            n *= 10;
            n += @intCast(self.peek(0));
            try self.advance(1);
        }
        return Token{ .type = TokenType.number, .lexeme = self.source[start..self.pos], .line = self.line };
    }

    fn id(self: *Lexer) !Token {
        const start = self.pos;
        while (std.ascii.isAlphanumeric(self.peek(0))) {
            try self.advance(1);
        }
        return Token{ .type = TokenType.id, .lexeme = self.source[start..self.pos], .line = self.line };
    }

    // Utils functions
    inline fn peek(self: *const Lexer, offset: ?usize) u8 {
        const offs = offset orelse 0;
        return if (self.pos + offs < self.source.len) self.source[self.pos + offs] else 0x00;
    }

    inline fn look_ahead(self: *const Lexer, len: usize) []u8 {
        if (self.pos + len >= self.source.len) {
            return "";
        }
        return self.source[self.pos .. self.pos + len];
    }

    inline fn advance(self: *Lexer, offset: ?usize) !void {
        const offs = offset orelse 1;
        if (self.pos + offs <= self.source.len) {
            self.pos += offs;
        } else {
            return Error.OutOfBounds;
        }
    }

    inline fn isAtEnd(self: *const Lexer) bool {
        return self.pos >= self.source.len;
    }

    fn skipWhitespace(self: *Lexer) Error!void {
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
