const std = @import("std");

const Error = error{NullLexeme};

pub const TokenType = enum {
    // Reserved keywords
    function_kw,
    return_kw,

    // Reserved control flow keywords
    if_kw,
    else_kw,
    while_kw,
    for_kw,
    break_kw,
    continue_kw,

    assign,

    lparen,
    rparen,
    lbrace,
    rbrace,
    lbrack,
    rbrack,

    comma,
    semi,

    eof,
    eol,

    // Binary math operator
    plus,
    minus,
    mul,
    div,
    mod,

    // Comparisons
    le,
    lt,
    eq,
    ge,
    gt,

    // Value associated token,
    string,
    integer,
    id,

    // Debug purpose only
    dummy,
};

pub const Token = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    type: TokenType,
    lexeme: ?[]const u8,
    line: usize,

    pub fn init(token_type: TokenType, lexeme: []const u8, line: usize, allocator: std.mem.Allocator) !Token {
        return Token{
            .allocator = allocator,
            .type = token_type,
            .lexeme = try allocator.dupe(u8, lexeme),
            .line = line,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.lexeme.?);
        self.lexeme = null;
    }

    pub fn getToken(self: *const Self) !*const Token {
        if (self.lexeme == null) {
            return Error.NullLexeme;
        } else {
            return self;
        }
    }

    pub fn getLexeme(self: *const Self) ![]const u8 {
        if (self.lexeme == null) {
            return Error.NullLexeme;
        } else {
            return self.lexeme.?;
        }
    }

    pub fn str(self: @This()) []const u8 {
        return std.fmt.bufPrint("{}:\"{?}\" l{}", .{ self.type, self.lexeme, self.line });
    }
};
