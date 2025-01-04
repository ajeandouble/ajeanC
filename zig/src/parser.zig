const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;
const AstNode = @import("./ast_nodes.zig");
const Node = AstNode.Node;
const res_kw = @import("./lex_constants.zig");

const NotImplemented = error{NotImplemented}.NotImplemented;

const Error = error{ ParsingError, BadToken, UnexpectedEndOfInput, MissingSemiColumn, NullTokens, NullLexeme, UnexpectedNodeType };

pub const Parser = struct {
    const Self = @This();
    tokens: ?std.ArrayList(Token),
    tok_idx: usize = 0,
    arena: std.heap.ArenaAllocator,

    ast: *const Node = undefined,

    pub fn init(tokens_slice: []const Token, allocator: std.mem.Allocator) !Self {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const arena_alloc = arena.allocator();
        var token_list = std.ArrayList(Token).init(arena_alloc);
        try token_list.ensureTotalCapacity(tokens_slice.len);

        for (tokens_slice) |token| {
            var lexeme: []const u8 = undefined;
            if (token.lexeme != null) {
                lexeme = try arena_alloc.dupe(u8, token.lexeme.?);
            } else {
                lexeme = try arena_alloc.dupe(u8, "");
            }
            const new_token = try Token.init(token.type, lexeme, token.line, arena_alloc);
            try token_list.append(new_token);
        }

        return Self{
            .arena = arena,
            .tokens = token_list,
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
        self.tokens = null;
    }

    // Utils
    fn makeNode(self: *Self, node: Node) !*Node {
        const allocator = self.arena.allocator();
        const node_ptr = try allocator.create(Node);
        node_ptr.* = node;
        return node_ptr;
    }

    fn eat(self: *Self, typ: TokenType) Error!void {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());

        if (token.type != typ) {
            dbg.print("Got bad token {}, expected {}\n", .{ typ, token.type }, @src());
            return Error.BadToken;
        }
        dbg.print("Ate {} == {s} and it was delicious\n", .{ typ, token.lexeme.? }, @src());
        self.tok_idx += 1;
    }

    pub inline fn getTokens(self: *const Self) ![]const Token {
        if (self.tokens == null) {
            return Error.NullTokens;
        }
        return self.tokens.?.items;
    }

    fn current(self: *const Self) !(?Token) {
        const tokens = try self.getTokens();
        const token: ?Token = if (self.tok_idx < tokens.len) tokens[self.tok_idx] else null;
        if (token != null and token.?.lexeme == null) {
            return Error.NullLexeme;
        }
        return token;
    }

    fn peek(self: *const Self, offset: usize) !(?Token) {
        const tokens = try self.getTokens();
        const token = if (self.tok_idx + offset < tokens.len) tokens[self.tok_idx + offset] else null;
        if (token != null and token.?.lexeme == null) {
            return Error.NullLexeme;
        }
        return token;
    }

    // Terminal symbols
    pub fn parseNumber(self: *Self) anyerror!*Node {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        try self.eat(TokenType.integer);
        const n = try std.fmt.parseInt(i64, try token.getLexeme(), 10);
        const node = try self.makeNode(Node{ .num = try AstNode.Num.make(AstNode.Num{ .token = token, .value = n }, self.arena.allocator()) });
        return node;
    }

    pub fn parseVariable(self: *Self) anyerror!*Node {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        try self.eat(TokenType.id);
        const id = try self.arena.allocator().dupe(u8, try token.getLexeme());
        const node = try self.makeNode(Node{ .variable = try AstNode.Variable.make(AstNode.Variable{ .token = token, .id = id }, self.arena.allocator()) });
        return node;
    }

    // Parsing non-terminals
    pub fn parseAssignment(self: *Self) anyerror!*Node {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        const lhs = try self.parseVariable();
        const assign_token = try self.current() orelse return Error.UnexpectedEndOfInput;
        try self.eat(TokenType.assign);
        const rhs = try self.parseExpr();
        return try self.makeNode(Node{ .binop = try AstNode.BinOp.make(AstNode.BinOp{ .token = assign_token, .lhs = lhs, .rhs = rhs }, self.arena.allocator()) });
    }

    pub fn parseCallArgs(self: *Self) anyerror!std.ArrayList(*Node) {
        var token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        var args = std.ArrayList(*Node).init(self.arena.allocator());
        while (token.type != TokenType.rparen) {
            const expr = try self.parseExpr();
            try args.append(expr);
            token = try self.current() orelse return Error.UnexpectedEndOfInput;
            if (token.type == TokenType.rparen) break;
            try self.eat(TokenType.comma);
        }
        return args;
    }

    pub fn parseFuncCall(self: *Self) anyerror!*Node {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        try self.eat(TokenType.id);
        try self.eat(TokenType.lparen);
        const args = try self.parseCallArgs();
        try self.eat(TokenType.rparen);

        // Create FunctionCall first
        const id = try self.arena.allocator().dupe(u8, try token.getLexeme());
        const func_call = try AstNode.FunctionCall.make(AstNode.FunctionCall{
            .token = token,
            .id = id,
            .args = args,
        }, self.arena.allocator());

        const node = try self.arena.allocator().create(Node);
        node.* = Node{ .func_call = func_call };

        return node;
    }

    pub fn parseFactor(self: *Self) anyerror!*Node {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        var node: *Node = undefined;
        switch (token.type) {
            .integer => node = try self.parseNumber(),
            .id => node = {
                const next_token = try self.peek(1) orelse return Error.UnexpectedEndOfInput;
                if (next_token.type == TokenType.lparen) {
                    return try self.parseFuncCall();
                } else {
                    return try self.parseVariable();
                }
            },
            .lparen => {
                dbg.print("yo", .{}, @src());
                try self.eat(TokenType.lparen);
                node = try self.parseExpr();
                try self.eat(TokenType.rparen);
            },
            .plus, .minus => {
                try self.eat(token.type);
                const value = try self.parseFactor();
                node = try self.makeNode(Node{ .unaryop = try AstNode.UnaryOp.make(AstNode.UnaryOp{ .token = token, .value = value }, self.arena.allocator()) });
            },
            else => {
                return Error.BadToken;
            },
        }
        // TODO: check for unary ops (plus, minus), ids and numbers
        return node;
    }

    pub fn parseTerm(self: *Self) anyerror!*Node {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        var node = try self.parseFactor();

        var current_token = try self.current() orelse return node;
        while (current_token.type == TokenType.mul or current_token.type == TokenType.div) {
            // dbg.print("{} \"{s}\"\n", .{ current_token.type, try current_token.getLexeme() }, @src());
            try self.eat(current_token.type);
            const rhs = try self.parseFactor();
            const lhs = node;
            const binop = try self.makeNode(Node{ .binop = try AstNode.BinOp.make(AstNode.BinOp{ .token = current_token, .lhs = lhs, .rhs = rhs }, self.arena.allocator()) });
            node = binop;
            current_token = try self.current() orelse break;
        }
        return node;
    }

    pub fn parseArithmetic(self: *Self) anyerror!*Node {
        var token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        var node = try self.parseTerm();

        token = try self.current() orelse return node;

        while (token.type == TokenType.plus or token.type == TokenType.minus) {
            //dbg.print("{} idx={}\n", .{ token.type, self.tok_idx }, @src());
            try self.eat(token.type);
            const rhs = try self.parseTerm();
            const lhs = node;
            const binop = try self.makeNode(Node{ .binop = try AstNode.BinOp.make(AstNode.BinOp{ .token = token, .lhs = lhs, .rhs = rhs }, self.arena.allocator()) });
            node = binop;
            token = try self.current() orelse break;
        }
        return node;
    }

    pub fn parseExpr(self: *Self) anyerror!*Node {
        var curr_token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ curr_token.type, try curr_token.getLexeme() }, @src());
        var node = try self.parseArithmetic();
        while (true) {
            curr_token = try self.current() orelse return node;
            dbg.print("{} \"{s}\"\n", .{ curr_token.type, curr_token.lexeme.? }, @src());
            switch (curr_token.type) {
                .le, .lt, .eq, .ge, .gt => {
                    const saved_node = node;
                    //dbg.print("{} \"{s}\"\n", .{ curr_token.type, curr_token.lexeme }, @src());
                    try self.eat(curr_token.type);
                    node = try self.makeNode(Node{ .binop = try AstNode.BinOp.make(AstNode.BinOp{ .token = curr_token, .lhs = saved_node, .rhs = try self.parseExpr() }, self.arena.allocator()) });
                },
                else => break,
            }
        }
        return node;
    }

    pub fn parseReturnStatement(self: *Self) anyerror!*Node {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        try self.eat(TokenType.return_kw);
        const expr = try self.parseExpr();
        try self.eat(TokenType.semi);
        const ret = try AstNode.Return.make(AstNode.Return{ .token = token, .expr = expr }, self.arena.allocator());
        return try self.makeNode(Node{ .ret = ret });
    }

    pub fn parseIfBlock(self: *Self) anyerror!*Node {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        try self.eat(TokenType.if_kw);
        try self.eat(TokenType.lparen);
        const expr = try self.parseExpr();
        try self.eat(TokenType.rparen);
        const statements = try self.parseCompoundStatement();
        const if_block = try AstNode.IfBlock.make(AstNode.IfBlock{ .expr = expr, .statements = statements, .token = token }, self.arena.allocator());
        return self.makeNode(Node{ .if_block = if_block });
    }

    pub fn parseStatement(self: *Self) anyerror!*Node {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        switch (token.type) {
            .integer, .lparen, .rparen, .plus, .minus => {
                const expr = try self.parseExpr();
                try self.eat(TokenType.semi);
                return expr;
            },
            .id => {
                const next_token = try self.peek(1) orelse return Error.UnexpectedEndOfInput;
                switch (next_token.type) {
                    .assign => {
                        const assignment = try self.parseAssignment();
                        try self.eat(TokenType.semi);
                        return assignment;
                    },
                    else => {
                        const expr = try self.parseExpr();
                        try self.eat(TokenType.semi);
                        return expr;
                    },
                }
            },
            .if_kw => {
                return self.parseIfBlock();
            },
            .return_kw => {
                return self.parseReturnStatement();
            },
            else => {
                return Error.BadToken;
            },
        }
        // TODO: statements parsing
        return Error.BadToken;
    }

    pub fn parseLocalStatements(self: *Self) anyerror!std.ArrayList(*Node) {
        var token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        var statements = std.ArrayList(*Node).init(self.arena.allocator());
        while (token.type != TokenType.rbrace) {
            dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
            try statements.append(try self.parseStatement());
            token = try self.current() orelse return Error.UnexpectedEndOfInput;
        }
        return statements;
    }

    pub fn parseCompoundStatement(self: *Self) anyerror!std.ArrayList(*Node) {
        const token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        try self.eat(TokenType.lbrace);
        const statements = try self.parseLocalStatements();
        try self.eat(TokenType.rbrace);
        return statements;
    }

    pub fn parseDeclArgs(self: *Self) !std.ArrayList(*Node) {
        var token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        var args = std.ArrayList(*Node).init(self.arena.allocator());
        while (token.type != TokenType.rparen) {
            const expr = try self.parseVariable();
            try args.append(expr);
            token = try self.current() orelse return Error.UnexpectedEndOfInput;
            dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
            if (token.type == TokenType.rparen) break;
            try self.eat(TokenType.comma);
            dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        }
        return args;
    }

    pub fn parseFuncDecl(self: *Self) !*Node {
        var token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());

        try self.eat(TokenType.function_kw);
        token = try self.current() orelse return Error.UnexpectedEndOfInput;
        const func_id = try self.arena.allocator().dupe(u8, token.lexeme.?);
        dbg.print("function \"{s}\"\n", .{func_id}, @src());
        try self.eat(TokenType.id);
        try self.eat(TokenType.lparen);
        const args = try self.parseDeclArgs();
        try self.eat(TokenType.rparen);
        const body = try self.parseCompoundStatement();
        return self.makeNode(Node{ .func_decl = try AstNode.FunctionDecl.make(AstNode.FunctionDecl{ .id = func_id, .token = token, .statements = body, .args = args }, self.arena.allocator()) });
    }

    pub fn parseGlobalStatements(self: *Self) !Node {
        var token = try self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, try token.getLexeme() }, @src());
        var global_statements = std.ArrayList(*Node).init(self.arena.allocator());
        var functions_decls = std.ArrayList(*Node).init(self.arena.allocator());
        while (token.type != TokenType.eof) {
            dbg.print("{} {s}\n", .{ token.type, try token.getLexeme() }, @src());
            switch (token.type) {
                TokenType.id => {
                    try global_statements.append(try self.parseAssignment());
                    try self.eat(TokenType.semi);
                },
                TokenType.function_kw => {
                    try functions_decls.append(try self.parseFuncDecl());
                },
                else => {
                    return Error.BadToken;
                },
            }
            token = try self.current() orelse return Error.UnexpectedEndOfInput;
        }

        return Node{ .program = try AstNode.Program.make(AstNode.Program{ .id = "main", .global_statements = global_statements, .functions = functions_decls }, self.arena.allocator()) };
    }

    pub fn parseProgram(self: *Self) !*AstNode.Program {
        const parsed_program = try self.arena.allocator().create(AstNode.Program);
        const node = try self.parseGlobalStatements();
        switch (node) {
            .program => |program| {
                parsed_program.* = program.*;
                return parsed_program;
            },
            else => {
                return Error.UnexpectedNodeType;
            },
        }
    }

    pub fn parse(self: *Self) !*AstNode.Program {
        const root_node = self.parseProgram() catch |err| {
            switch (err) {
                Error.BadToken => {
                    dbg.print("Bad Token: {}\n", .{(try self.current() orelse return Error.ParsingError).type}, @src());
                    return Error.ParsingError;
                },
                else => {
                    dbg.print("Error: {}\n", .{err}, @src());
                    return err;
                },
            }
        };

        // return
        return root_node;
        // return try self.makeNode(Node{ .num = try AstNodes.Num.make(AstNodes.Num{ .token = Token{ .type = TokenType.integer, .lexeme = "42", .line = 0, .allocator = self.arena.allocator() }, .value = 42 }, self.arena.allocator()) });
    }
};

const expect = std.testing.expect;

// Tests
fn setupParserTest(tokens: []Token) !Parser {
    const allocator = std.testing.allocator;
    return try Parser.init(tokens, allocator);
}

fn destroyParser(parser: *Parser) void {
    parser.deinit();
}

// Helper type checking functions
fn isBinOp(node: *const Node) bool {
    return switch (node.*) {
        .binop => true,
        else => false,
    };
}

fn isNum(node: *const Node) bool {
    return switch (node.*) {
        .num => true,
        else => false,
    };
}

fn isVariable(node: *const Node) bool {
    return switch (node.*) {
        .variable => true,
        else => false,
    };
}

fn isFuncCall(node: *const Node) bool {
    return switch (node.*) {
        .func_call => true,
        else => false,
    };
}

fn isFuncDecl(node: *const Node) bool {
    return switch (node.*) {
        .func_decl => true,
        else => false,
    };
}

fn isProgram(node: *const Node) bool {
    return switch (node.*) {
        .program => true,
        else => false,
    };
}

test "parser init and cleanup" {
    var tokens = [_]Token{
        Token{ .type = TokenType.integer, .lexeme = "41", .line = 0, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    destroyParser(&parser);
}

test "parseExpr - simple arithmetic" {
    var tokens = [_]Token{
        Token{ .type = TokenType.integer, .lexeme = "3", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.plus, .lexeme = "+", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "4", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.semi, .lexeme = ";", .line = 0, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer destroyParser(&parser);

    const ast = try parser.parseExpr();

    try std.testing.expect(isBinOp(ast));
    try std.testing.expectEqual(ast.binop.token.type, TokenType.plus);

    try std.testing.expect(isNum(ast.binop.lhs));
    try std.testing.expectEqualStrings(ast.binop.lhs.*.num.token.lexeme.?, "3");
    try std.testing.expectEqual(ast.binop.lhs.*.num.value, 3);

    try std.testing.expect(isNum(ast.binop.rhs));
    try std.testing.expectEqual(ast.binop.rhs.*.num.value, 4);
}

test "parseExpr - arithmetic, parentheses" {
    var tokens = [_]Token{
        Token{ .type = TokenType.integer, .lexeme = "41", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.plus, .lexeme = "+", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "1", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.div, .lexeme = "/", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.lparen, .lexeme = "(", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "9", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.mul, .lexeme = "*", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "3", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.rparen, .lexeme = ")", .line = 1, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();
    const ast = try parser.parseExpr();
    try std.testing.expect(isBinOp(ast));
    try std.testing.expectEqual(ast.binop.token.type, TokenType.plus);

    try std.testing.expect(isNum(ast.binop.lhs));
    const node_41 = ast.binop.lhs.*.num;
    try std.testing.expectEqual(node_41.value, 41);

    try std.testing.expect(isBinOp(ast.binop.rhs));
    const node_binop_div = ast.binop.rhs.*.binop;
    try std.testing.expectEqual(node_binop_div.token.type, TokenType.div);

    const node_1 = node_binop_div.lhs.*.num;
    try std.testing.expectEqual(node_1.token.type, TokenType.integer);
    try std.testing.expectEqual(node_1.value, 1);

    const node_binop_mul = node_binop_div.rhs.*.binop;
    try std.testing.expectEqual(node_binop_mul.token.type, TokenType.mul);

    const node_9 = node_binop_mul.lhs.*.num;
    try std.testing.expectEqualStrings(node_9.token.lexeme.?, "9");
    try std.testing.expectEqual(node_9.token.type, TokenType.integer);
    try std.testing.expectEqual(node_9.value, 9);

    const node_3 = node_binop_mul.rhs.*.num;
    try std.testing.expectEqualStrings(node_3.token.lexeme.?, "3");
    try std.testing.expectEqual(node_3.token.type, TokenType.integer);
    try std.testing.expectEqual(node_3.value, 3);
}

test "parseExpr - arithmetic, parentheses, variable" {
    var tokens = [_]Token{
        Token{ .type = TokenType.integer, .lexeme = "1", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.plus, .lexeme = "+", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lparen, .lexeme = "(", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "a", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.mul, .lexeme = "*", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "9", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.rparen, .lexeme = ")", .line = 1, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();
    const ast = try parser.parseExpr();
    try std.testing.expect(isBinOp(ast));
    try std.testing.expectEqual(ast.binop.token.type, TokenType.plus);

    try std.testing.expect(isNum(ast.binop.lhs));
    const num_1 = ast.binop.lhs.*.num;
    try std.testing.expectEqual(num_1.value, 1);

    try std.testing.expect(isBinOp(ast.binop.rhs));
    const binop_mul = ast.binop.rhs.*.binop;
    try std.testing.expectEqual(binop_mul.token.type, TokenType.mul);

    try std.testing.expect(isVariable(binop_mul.lhs));
    const var_a = binop_mul.lhs.*.variable;
    try std.testing.expectEqual(var_a.token.type, TokenType.id);
    try std.testing.expectEqualStrings(var_a.id, "a");

    const num_9 = binop_mul.rhs.*.num;
    try std.testing.expectEqual(num_9.token.type, TokenType.integer);
    try std.testing.expectEqual(num_9.value, 9);
}

test "parseExpr - arithmetic, parentheses, variable, comparison" {
    var tokens = [_]Token{
        Token{ .type = TokenType.integer, .lexeme = "1", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.plus, .lexeme = "+", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lparen, .lexeme = "(", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "a", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.gt, .lexeme = ">", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "9", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.eq, .lexeme = "==", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "3", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rparen, .lexeme = ")", .line = 0, .allocator = undefined },
    };
    // // 1 [+] ( a > 9 == 3 )
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();
    const ast = try parser.parseExpr();
    try std.testing.expect(isBinOp(ast));
    try std.testing.expectEqual(ast.binop.token.type, TokenType.plus);

    // [1] + ( a > 9 == 3 )
    try std.testing.expect(isNum(ast.binop.lhs));
    const num_1 = ast.binop.lhs.*.num;
    try std.testing.expectEqual(num_1.value, 1);

    // 1 + ( a [>] 9 == 3 )
    try std.testing.expect(isBinOp(ast.binop.rhs));
    const binop_gt = ast.binop.rhs.*.binop;
    try std.testing.expectEqual(binop_gt.token.type, TokenType.gt);

    // 1 + ( [a] > 9 == 3 )
    try std.testing.expect(isVariable((binop_gt.lhs)));
    const var_a = binop_gt.lhs.*.variable;
    try std.testing.expectEqual(var_a.token.type, TokenType.id);
    try std.testing.expectEqualStrings(var_a.id, "a");

    // 1 + ( a > 9 [==] 3 )
    try std.testing.expect(isBinOp((binop_gt.rhs)));
    const binop_eq = binop_gt.rhs.*.binop;
    try std.testing.expectEqual(binop_eq.token.type, TokenType.eq);

    // 1 + ( a > [9] == 3 )
    try std.testing.expect(isNum((binop_eq.lhs)));
    const num_9 = binop_eq.lhs.*.num;
    try std.testing.expectEqual(num_9.token.type, TokenType.integer);
    try std.testing.expectEqual(num_9.value, 9);

    // 1 + ( a > 9 == [3] )
    try std.testing.expect(isNum((binop_eq.rhs)));
    const num_3 = binop_eq.rhs.*.num;
    try std.testing.expectEqual(num_3.token.type, TokenType.integer);
    try std.testing.expectEqual(num_3.value, 3);
}

test "parseAssignment" {
    var tokens = [_]Token{
        Token{ .type = TokenType.id, .lexeme = "a", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.assign, .lexeme = "=", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "2", .line = 0, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();

    const ast = try parser.parseAssignment();
    try std.testing.expect(isBinOp(ast));
}

test "parseAssignment - arithmetic, variables, parentheses" {
    var tokens = [_]Token{
        Token{ .type = TokenType.id, .lexeme = "a", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.assign, .lexeme = "=", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "b", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.mul, .lexeme = "*", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.lparen, .lexeme = "(", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "c", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.plus, .lexeme = "+", .line = 1, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "3", .line = 3, .allocator = undefined },
        Token{ .type = TokenType.rparen, .lexeme = ")", .line = 3, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();
    const ast = try parser.parseAssignment();
    try std.testing.expect(isBinOp(ast));
    try std.testing.expectEqual(ast.binop.token.type, TokenType.assign);

    try std.testing.expect(isVariable(ast.binop.lhs));
    const var_a = ast.binop.lhs.*.variable;
    try std.testing.expectEqual(var_a.token.type, TokenType.id);
    try std.testing.expectEqualStrings(var_a.token.lexeme.?, "a");
    try std.testing.expectEqualStrings(var_a.id, "a");

    try std.testing.expect(isBinOp(ast.binop.rhs));
    const binop_mul = ast.binop.rhs.*.binop;
    try std.testing.expectEqual(binop_mul.token.type, TokenType.mul);

    try std.testing.expect(isVariable(binop_mul.lhs));
    const var_b = binop_mul.lhs.*.variable;
    try std.testing.expectEqual(var_b.token.type, TokenType.id);
    try std.testing.expectEqualStrings(var_b.id, "b");

    try std.testing.expect(isBinOp(binop_mul.rhs));
    const binop_plus = binop_mul.rhs.*.binop;
    try std.testing.expectEqual(binop_plus.token.type, TokenType.plus);

    try std.testing.expect(isVariable(binop_plus.lhs));
    const var_c = binop_plus.lhs.*.variable;
    try std.testing.expectEqual(var_c.token.type, TokenType.id);

    try std.testing.expect(isNum(binop_plus.rhs));
    const num_3 = binop_plus.rhs.*.num;
    try std.testing.expectEqual(num_3.token.type, TokenType.integer);
    try std.testing.expectEqual(num_3.value, 3);
}

test "parseExpr - function call - 1 arg" {
    var tokens = [_]Token{ Token{ .type = TokenType.id, .lexeme = "a", .line = 0, .allocator = undefined }, Token{ .type = TokenType.lparen, .lexeme = "(", .line = 0, .allocator = undefined }, Token{ .type = TokenType.id, .lexeme = "b", .line = 1, .allocator = undefined }, Token{ .type = TokenType.rparen, .lexeme = ")", .line = 1, .allocator = undefined } };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();
    const ast = try parser.parseExpr();

    try std.testing.expect(isFuncCall(ast));
    try std.testing.expectEqualStrings(ast.func_call.id, "a");

    try std.testing.expect(isVariable(ast.func_call.*.args.items[0]));
    const expr_b = ast.func_call.*.args.items[0].*.variable;
    try std.testing.expectEqual(expr_b.token.type, TokenType.id);
    try std.testing.expectEqualStrings(expr_b.token.lexeme.?, "b");
    try std.testing.expectEqualStrings(expr_b.id, "b");
}

test "parseExpr - function call - 2 args" {
    var tokens = [_]Token{
        Token{ .type = TokenType.id, .lexeme = "a", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lparen, .lexeme = "(", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "b", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.comma, .lexeme = ",", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "c", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rparen, .lexeme = ")", .line = 0, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();
    const ast = try parser.parseExpr();
    try std.testing.expect(isFuncCall(ast));
    try std.testing.expectEqualStrings(ast.func_call.id, "a");

    try std.testing.expect(isVariable(ast.func_call.*.args.items[0]));
    const expr_b = ast.func_call.*.args.items[0].*.variable;
    try std.testing.expectEqual(expr_b.token.type, TokenType.id);
    try std.testing.expectEqualStrings(expr_b.token.lexeme.?, "b");
    try std.testing.expectEqualStrings(expr_b.id, "b");

    try std.testing.expect(isVariable(ast.func_call.*.args.items[1]));
    const expr_c = ast.func_call.*.args.items[1].*.variable;
    try std.testing.expectEqual(expr_c.token.type, TokenType.id);
    try std.testing.expectEqualStrings(expr_c.token.lexeme.?, "c");
    try std.testing.expectEqualStrings(expr_c.id, "c");
}

test "parseCompoundStatement - function call - 2 args - 2 exprs" {
    var tokens = [_]Token{
        Token{ .type = TokenType.lbrace, .lexeme = "{", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "a", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.assign, .lexeme = "=", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "b", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.semi, .lexeme = ";", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "42", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.semi, .lexeme = ";", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rbrace, .lexeme = "}", .line = 0, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();
    const ast = try parser.parseCompoundStatement();

    try std.testing.expect(isBinOp(ast.items[0]));
    const statement_1 = ast.items[0].binop.*;
    try std.testing.expectEqual(statement_1.token.type, TokenType.assign);

    try std.testing.expect(isVariable(statement_1.lhs));
    const var_a = statement_1.lhs.variable.*;
    try std.testing.expectEqualStrings(var_a.id, "a");

    try std.testing.expect(isVariable(statement_1.rhs));
    const var_b = statement_1.rhs.variable.*;
    try std.testing.expectEqualStrings(var_b.id, "b");
}

test "parseProgram - function main" {
    var tokens = [_]Token{
        Token{ .type = TokenType.function_kw, .lexeme = "function", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "main", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lparen, .lexeme = "(", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rparen, .lexeme = ")", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lbrace, .lexeme = "{", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rbrace, .lexeme = "}", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.eof, .lexeme = "", .line = 0, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();

    const program = try parser.parse();
    try std.testing.expectEqual(program.functions.items.len, 1);
    try std.testing.expectEqual(program.global_statements.items.len, 0);

    const func_main = program.functions.items[0].*.func_decl;
    try std.testing.expectEqualStrings(func_main.id, "main");
    try std.testing.expectEqual(func_main.statements.items.len, 0);
}

test "parseProgram - function main and function declaration" {
    var tokens = [_]Token{
        Token{ .type = TokenType.function_kw, .lexeme = "function", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "main", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lparen, .lexeme = "(", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rparen, .lexeme = ")", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lbrace, .lexeme = "{", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rbrace, .lexeme = "}", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.function_kw, .lexeme = "function", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "myFunc", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lparen, .lexeme = "(", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rparen, .lexeme = ")", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lbrace, .lexeme = "{", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "a", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.assign, .lexeme = "=", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "42", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.semi, .lexeme = ";", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rbrace, .lexeme = "}", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.eof, .lexeme = "", .line = 0, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();

    const program = try parser.parse();
    try std.testing.expectEqual(program.functions.items.len, 2);
    try std.testing.expectEqual(program.global_statements.items.len, 0);

    const func_main = program.functions.items[0].*.func_decl;
    try std.testing.expectEqualStrings(func_main.id, "main");
    try std.testing.expectEqual(func_main.statements.items.len, 0);

    const func_myFunc = program.functions.items[1].*.func_decl;
    try std.testing.expectEqualStrings(func_myFunc.id, "myFunc");
    try std.testing.expectEqual(func_myFunc.statements.items.len, 1);

    const myFunc_stmt = func_myFunc.statements.items;
    const myFunc_a_assign = myFunc_stmt[0];
    try std.testing.expect(isBinOp(myFunc_a_assign));
    try std.testing.expect(isVariable(myFunc_a_assign.binop.lhs));
    try std.testing.expect(isNum(myFunc_a_assign.binop.rhs));
}

test "parseProgram - main, func and global statements" {
    var tokens = [_]Token{
        Token{ .type = TokenType.id, .lexeme = "a", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.assign, .lexeme = "=", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.integer, .lexeme = "42", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.semi, .lexeme = ";", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "b", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.assign, .lexeme = "=", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "a", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.semi, .lexeme = ";", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.function_kw, .lexeme = "function", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.id, .lexeme = "main", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lparen, .lexeme = "(", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rparen, .lexeme = ")", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.lbrace, .lexeme = "{", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.rbrace, .lexeme = "}", .line = 0, .allocator = undefined },
        Token{ .type = TokenType.eof, .lexeme = "", .line = 0, .allocator = undefined },
    };
    var parser = try setupParserTest(&tokens);
    defer parser.deinit();

    const program = try parser.parse();
    try std.testing.expectEqual(program.functions.items.len, 1);
    try std.testing.expectEqual(program.global_statements.items.len, 2);

    try std.testing.expect(isBinOp(program.global_statements.items[0]));
    const stmt_a_assign_42 = program.global_statements.items[0].*.binop;
    try std.testing.expect(isVariable(stmt_a_assign_42.lhs));
    const stmt_a_assign_42_var_a = stmt_a_assign_42.lhs.*.variable;
    try std.testing.expectEqualStrings(
        "a",
        stmt_a_assign_42_var_a.id,
    );

    // const stmt_a_assign_42_42
    // try std.testing.expectEqual(stmt_a_assign_42.lhs
    try std.testing.expect(isNum(stmt_a_assign_42.rhs));

    const func_main = program.functions.items[0].*.func_decl;
    try std.testing.expectEqualStrings(func_main.id, "main");
    try std.testing.expectEqual(func_main.statements.items.len, 0);
}
