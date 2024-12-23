const std = @import("std");

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
    number,
    id,

    // Debug purpose only
    dummy,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,

    pub fn init(token_type: TokenType, lexeme: []const u8, line: usize) Token {
        return Token{
            .type = token_type,
            .lexeme = lexeme,
            .line = line,
        };
    }
};
