const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;
const AstNodes = @import("./ast_nodes.zig");
const Node = AstNodes.Node;

const NotImplemented = error{NotImplemented}.NotImplemented;

const Error = error{ ParsingError, BadToken, UnexpectedEndOfInput, MissingSemiColumn };

pub const Parser = struct {
    const Self = @This();
    tokens: []Token = undefined,
    tok_idx: usize = 0,
    allocator: std.mem.Allocator = undefined,

    pub fn init(tokens: []Token, allocator: std.mem.Allocator) !Self {
        const parser = Self{ .tokens = try allocator.alloc(Token, tokens.len), .allocator = allocator };
        @memcpy(parser.tokens, tokens);
        return parser;
    }

    // Utils
    fn makeNode(self: *Self, node: Node) !*Node {
        const node_ptr = try self.allocator.create(Node);
        node_ptr.* = node;
        return node_ptr;
    }

    fn eat(self: *Self, typ: TokenType) Error!void {
        const token = self.current() orelse return Error.UnexpectedEndOfInput;
        if (token.type != typ) {
            dbg.print("Got bad token {}, expected {}\n", .{ typ, token.type }, @src());
            return Error.BadToken;
        }
        dbg.print("Ate {}=={s} and it was delicious\n", .{ typ, token.lexeme }, @src());
        self.tok_idx += 1;
    }

    fn current(self: *const Self) ?Token {
        return if (self.tok_idx < self.tokens.len) self.tokens[self.tok_idx] else null;
    }

    fn peek(self: *const Self, offset: usize) ?Token {
        if (self.tok_idx + offset >= self.tokens.len) {
            return null;
        }
        return self.tokens[self.tok_idx + offset];
    }

    // Terminal symbols
    pub fn parseNumber(self: *Self) anyerror!*Node {
        const token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        try self.eat(TokenType.integer);
        const n = try std.fmt.parseInt(i64, token.lexeme, 10);
        const node = try self.makeNode(Node{ .num = try AstNodes.Num.make(AstNodes.Num{ .token = token, .value = n }, self.allocator) });
        return node;
    }

    pub fn parseVariable(self: *Self) anyerror!*Node {
        const token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        try self.eat(TokenType.id);
        const id = try self.allocator.dupe(u8, token.lexeme);
        const node = try self.makeNode(Node{ .variable = try AstNodes.Variable.make(AstNodes.Variable{ .token = token, .id = id }, self.allocator) });
        return node;
    }

    // Parsing non-terminals
    pub fn parseAssignment(self: *Self) anyerror!*Node {
        const token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        const lhs = try self.parseVariable();
        const assign_token = self.current() orelse return Error.UnexpectedEndOfInput;
        try self.eat(TokenType.assign);
        const rhs = try self.parseExpr();
        return try self.makeNode(Node{ .binop = try AstNodes.BinOp.make(AstNodes.BinOp{ .token = assign_token, .lhs = lhs, .rhs = rhs }, self.allocator) });
    }

    pub fn parseCallArgs(self: *Self) anyerror!std.ArrayList(*Node) {
        var token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        var args = std.ArrayList(*Node).init(self.allocator);
        while (token.type != TokenType.rparen) {
            const expr = try self.parseExpr();
            try args.append(expr);
            token = self.current() orelse return Error.UnexpectedEndOfInput;
            dbg.print("yo--------T O K E N={}\n", .{token.type}, @src());

            if (token.type == TokenType.rparen) break;
            try self.eat(TokenType.comma);
        }
        return args;
    }
    pub fn parseFuncCall(self: *Self) anyerror!*Node {
        const token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        try self.eat(TokenType.id);
        try self.eat(TokenType.lparen);
        const args = try self.parseCallArgs();
        try self.eat(TokenType.rparen);

        // Create FunctionCall first
        const id = try self.allocator.dupe(u8, token.lexeme);
        const func_call = try AstNodes.FunctionCall.make(AstNodes.FunctionCall{
            .token = token,
            .id = id,
            .args = args,
        }, self.allocator);

        // Then create the Node separately
        const node = try self.allocator.create(Node);
        node.* = Node{ .func_call = func_call };

        return node;
    }

    pub fn parseFactor(self: *Self) anyerror!*Node {
        const token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());

        var node: *Node = undefined;
        switch (token.type) {
            .integer => node = try self.parseNumber(),
            .id => node = {
                const next_token = self.peek(1) orelse return Error.UnexpectedEndOfInput;
                if (next_token.type == TokenType.lparen) {
                    return try self.parseFuncCall();
                } else {
                    return try self.parseVariable();
                }
            },
            .lparen => {
                try self.eat(TokenType.lparen);
                node = try self.parseExpr();
                try self.eat(TokenType.rparen);
            },
            .plus, .minus => {
                try self.eat(token.type);
                const value = try self.parseFactor();
                node = try self.makeNode(Node{ .unaryop = try AstNodes.UnaryOp.make(AstNodes.UnaryOp{ .token = token, .value = value }, self.allocator) });
            },
            else => return NotImplemented,
        }
        // TODO: check for unary ops (plus, minus), ids and numbers
        return node;
    }

    pub fn parseTerm(self: *Self) anyerror!*Node {
        const token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        var node = try self.parseFactor();

        var current_token = self.current() orelse return node;
        while (current_token.type == TokenType.mul or current_token.type == TokenType.div) {
            dbg.print("{} \"{s}\"\n", .{ current_token.type, current_token.lexeme }, @src());
            try self.eat(current_token.type);
            const rhs = try self.parseFactor();
            const lhs = node;
            const binop = try self.makeNode(Node{ .binop = try AstNodes.BinOp.make(AstNodes.BinOp{ .token = current_token, .lhs = lhs, .rhs = rhs }, self.allocator) });
            node = binop;
            current_token = self.current() orelse break;
        }
        return node;
    }

    pub fn parseArithmetic(self: *Self) anyerror!*Node {
        var token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        var node = try self.parseTerm();

        token = self.current() orelse return node;

        while (token.type == TokenType.plus or token.type == TokenType.minus) {
            dbg.print("{} idx={}\n", .{ token.type, self.tok_idx }, @src());
            try self.eat(token.type);
            const rhs = try self.parseTerm();
            const lhs = node;
            const binop = try self.makeNode(Node{ .binop = try AstNodes.BinOp.make(AstNodes.BinOp{ .token = token, .lhs = lhs, .rhs = rhs }, self.allocator) });
            node = binop;
            token = self.current() orelse break;
        }
        return node;
    }

    pub fn parseExpr(self: *Self) anyerror!*Node {
        var curr_token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ curr_token.type, curr_token.lexeme }, @src());
        var node = try self.parseArithmetic();
        while (true) {
            curr_token = self.current() orelse return node;
            dbg.print("{} \"{s}\"\n", .{ curr_token.type, curr_token.lexeme }, @src());
            switch (curr_token.type) {
                .le, .lt, .eq, .ge, .gt => {
                    const saved_node = node;
                    dbg.print("{} \"{s}\"\n", .{ curr_token.type, curr_token.lexeme }, @src());
                    try self.eat(curr_token.type);
                    node = try self.makeNode(Node{ .binop = try AstNodes.BinOp.make(AstNodes.BinOp{ .token = curr_token, .lhs = saved_node, .rhs = try self.parseExpr() }, self.allocator) });
                },
                else => break,
            }
        }
        dbg.print("yoo directly\n", .{}, @src());
        return node;
    }

    pub fn parseStatement(self: *Self) anyerror!*Node {
        const token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        switch (token.type) {
            .integer, .lparen, .rparen, .plus, .minus => {
                const node = try self.parseExpr();
                try self.eat(TokenType.semi);
                return node;
            },
            .id => {
                const next_token = self.peek(1) orelse return Error.UnexpectedEndOfInput;
                switch (next_token.type) {
                    .lparen => {
                        return NotImplemented;
                    },
                    .assign => {
                        return try self.parseAssignment();
                    },
                    else => {
                        const node = try self.parseExpr();
                        try self.eat(TokenType.semi);
                        return node;
                    },
                }
            },
            // TODO: if block
            // TODO: return_statement
            else => {},
        }
        // TODO: statements parsing
        return Error.BadToken;
    }

    pub fn parseLocalStatements(self: *Self) anyerror!std.ArrayList(*Node) {
        var token = self.current() orelse return Error.UnexpectedEndOfInput;
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        var statements = std.ArrayList(*Node).init(self.allocator);
        try statements.append((try self.parseStatement()));
        while (token.type != TokenType.rbrace) {
            try statements.append(try self.parseStatement());
            token = self.current() orelse return Error.UnexpectedEndOfInput;
        }
        return statements;
    }

    pub fn parseCompoundStatement(self: *Self) anyerror!std.ArrayList(*Node) {
        const token = self.current();
        if (token == null) {
            return Error.UnexpectedEndOfInput;
        }
        dbg.print("{} \"{s}\"\n", .{ token.?.type, token.?.lexeme }, @src());
        try self.eat(TokenType.lbrace);
        const statements = try self.parseLocalStatements();
        try self.eat(TokenType.rbrace);
        return statements;
    }

    // pub fn visit(self: *Self, node: *const Node) i64 {
    //     switch (node.*) {
    //         .num => |*num| {
    //             std.debug.print("num {} \n", .{num.*.value});
    //             return num.*.value;
    //             // dbg.print("{}({})\n", .{ num.*.token.type, num.*.value }, @src());
    //         },
    //         .binop => |*binop| {
    //             std.debug.print("binop {s} \n", .{binop.*.token.lexeme});

    //             // _ = binop;
    //             dbg.print("left\t{*}\n", .{binop.*.lhs}, @src());
    //             switch (binop.*.token.type) {
    //                 TokenType.plus => {
    //                     const l = self.visit(binop.*.lhs);
    //                     const r = self.visit(binop.*.rhs);
    //                 },
    //                 else => unreachable,
    //             }
    //             dbg.print("+\n", .{}, @src());
    //             dbg.print("right\t{*}\n", .{binop.*.rhs}, @src());
    //             // self.visit(binop.*.right);
    //         },
    //     }
    //     return 0;
    // }

    pub fn parse(self: *Self) !*Node {
        const root_node = self.parseExpr() catch |err| {
            switch (err) {
                Error.BadToken => {
                    dbg.print("Bad Token: {}\n", .{(self.current() orelse return Error.ParsingError).type}, @src());
                    return Error.ParsingError;
                },
                else => return err,
            }
        };
        _ = root_node;
        dbg.print("\n", .{}, @src());
        // _ = self.visit(root_node);

        // Dummy return value for dev rn
        return try self.makeNode(Node{ .num = try AstNodes.Num.make(AstNodes.Num{ .token = Token{ .type = TokenType.integer, .lexeme = "42", .line = 0 }, .value = 42 }, self.allocator) });
        // _ = num1;
        // const num2 = try Node.Num.init(Token{ .type = TokenType.integer, .lexeme = "1", .line = 1 });
        // _ = add;
    }
};

const expect = std.testing.expect;

fn setupTests() !void {}
fn teardownTests() !void {}

// Tests
fn destroyNode(node: ?*const Node) void {
    const allocator = std.testing.allocator;
    if (node) |n| {
        switch (n.*) {
            .num => |num| {
                allocator.destroy(num);
            },
            .binop => |binop| {
                destroyNode(binop.lhs);
                destroyNode(binop.rhs);
                allocator.destroy(binop);
            },
            .unaryop => |unaryop| {
                destroyNode(unaryop.value);
                allocator.destroy(unaryop);
            },
            .variable => |variable| {
                allocator.free(variable.id);
                allocator.destroy(variable);
            },
            .func_call => |call| {
                for (call.args.items) |expr| {
                    destroyNode(expr);
                }
                allocator.free(call.id);
                call.args.deinit();
                allocator.destroy(call);
            },
        }
        allocator.destroy(n);
    }
}

fn setupParserTest(tokens: []Token) !Parser {
    const allocator = std.testing.allocator;
    return Parser.init(tokens, allocator);
}

fn destroyParser(parser: Parser, ast: ?*const Node) void {
    if (ast != null) {
        destroyNode(ast);
    }
    const allocator = std.testing.allocator;
    allocator.free(parser.tokens);
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

test "parseExpr - simple arithmetic" {
    var tokens = [_]Token{
        Token.init(TokenType.integer, "3", 1),
        Token.init(TokenType.plus, "+", 1),
        Token.init(TokenType.integer, "4", 1),
        Token.init(TokenType.semi, ";", 1),
    };
    var parser = try setupParserTest(&tokens);
    const ast = try parser.parseExpr();
    try std.testing.expect(isBinOp(ast));
    try std.testing.expectEqual(ast.binop.token.type, TokenType.plus);

    try std.testing.expect(isNum(ast.binop.lhs));
    try std.testing.expectEqualStrings(ast.binop.lhs.*.num.token.lexeme, "3");
    try std.testing.expectEqual(ast.binop.lhs.*.num.value, 3);

    try std.testing.expect(isNum(ast.binop.rhs));
    try std.testing.expectEqual(ast.binop.rhs.*.num.value, 4);

    destroyParser(parser, ast);
}

test "parseExpr - arithmetic, parentheses" {
    var tokens = [_]Token{
        Token.init(TokenType.integer, "41", 0),
        Token.init(TokenType.plus, "+", 0),
        Token.init(TokenType.integer, "1", 1),
        Token.init(TokenType.div, "/", 1),
        Token.init(TokenType.lparen, "(", 1),
        Token.init(TokenType.integer, "9", 1),
        Token.init(TokenType.mul, "*", 1),
        Token.init(TokenType.integer, "3", 1),
        Token.init(TokenType.rparen, ")", 1),
    };
    var parser = try setupParserTest(&tokens);
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
    try std.testing.expectEqualStrings(node_9.token.lexeme, "9");
    try std.testing.expectEqual(node_9.token.type, TokenType.integer);
    try std.testing.expectEqual(node_9.value, 9);

    const node_3 = node_binop_mul.rhs.*.num;
    try std.testing.expectEqualStrings(node_3.token.lexeme, "3");
    try std.testing.expectEqual(node_3.token.type, TokenType.integer);
    try std.testing.expectEqual(node_3.value, 3);

    destroyParser(parser, ast);
}

test "parseExpr - arithmetic, parentheses, variable" {
    var tokens = [_]Token{
        Token.init(TokenType.integer, "1", 0),
        Token.init(TokenType.plus, "+", 0),
        Token.init(TokenType.lparen, "(", 1),
        Token.init(TokenType.id, "a", 1),
        Token.init(TokenType.mul, "*", 1),
        Token.init(TokenType.integer, "9", 1),
        Token.init(TokenType.rparen, ")", 1),
    };
    var parser = try setupParserTest(&tokens);
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

    destroyParser(parser, ast);
}

test "parseExpr - arithmetic, parentheses, variable, comparison" {
    var tokens = [_]Token{
        Token.init(TokenType.integer, "1", 0),
        Token.init(TokenType.plus, "+", 0),
        Token.init(TokenType.lparen, "(", 1),
        Token.init(TokenType.id, "a", 1),
        Token.init(TokenType.gt, ">", 1),
        Token.init(TokenType.integer, "9", 1),
        Token.init(TokenType.eq, "==", 1),
        Token.init(TokenType.integer, "3", 1),
        Token.init(TokenType.rparen, ")", 1),
    };
    // // 1 [+] ( a > 9 == 3 )
    var parser = try setupParserTest(&tokens);
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

    destroyParser(parser, ast);
}

test "parseAssignment" {
    var tokens = [_]Token{
        Token.init(TokenType.id, "a", 0),
        Token.init(TokenType.assign, "=", 0),
        Token.init(TokenType.integer, "2", 1),
    };
    var parser = try setupParserTest(&tokens);
    const ast = try parser.parseAssignment();
    try std.testing.expect(isBinOp(ast));
    destroyParser(parser, ast);
}

test "parseAssignment - arithmetic, variables, parentheses" {
    var tokens = [_]Token{
        Token.init(TokenType.id, "a", 0),
        Token.init(TokenType.assign, "=", 0),
        Token.init(TokenType.id, "b", 1),
        Token.init(TokenType.mul, "*", 1),
        Token.init(TokenType.lparen, "(", 1),
        Token.init(TokenType.id, "c", 1),
        Token.init(TokenType.plus, "+", 1),
        Token.init(TokenType.integer, "3", 3),
        Token.init(TokenType.rparen, ")", 100),
    };
    var parser = try setupParserTest(&tokens);
    const ast = try parser.parseAssignment();
    try std.testing.expect(isBinOp(ast));
    try std.testing.expectEqual(ast.binop.token.type, TokenType.assign);

    try std.testing.expect(isVariable(ast.binop.lhs));
    const var_a = ast.binop.lhs.*.variable;
    try std.testing.expectEqual(var_a.token.type, TokenType.id);
    try std.testing.expectEqualStrings(var_a.token.lexeme, "a");
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

    destroyParser(parser, ast);
}

test "parseExpr - function call - 1 arg" {
    var tokens = [_]Token{
        Token.init(TokenType.id, "a", 0),
        Token.init(TokenType.lparen, "(", 0),
        Token.init(TokenType.id, "b", 1),
        Token.init(TokenType.rparen, ")", 1),
    };
    var parser = try setupParserTest(&tokens);
    const ast = try parser.parseExpr();
    try std.testing.expect(isFuncCall(ast));
    try std.testing.expectEqualStrings(ast.func_call.id, "a");

    try std.testing.expect(isVariable(ast.func_call.*.args.items[0]));
    const expr_b = ast.func_call.*.args.items[0].*.variable;
    try std.testing.expectEqual(expr_b.token.type, TokenType.id);
    try std.testing.expectEqualStrings(expr_b.token.lexeme, "b");
    try std.testing.expectEqualStrings(expr_b.id, "b");

    destroyParser(parser, ast);
}

test "parseExpr - function call - 2 arg" {
    var tokens = [_]Token{
        Token.init(TokenType.id, "a", 0),
        Token.init(TokenType.lparen, "(", 0),
        Token.init(TokenType.id, "b", 1),
        Token.init(TokenType.comma, ",", 1),
        Token.init(TokenType.id, "c", 1),
        Token.init(TokenType.rparen, ")", 1),
    };
    var parser = try setupParserTest(&tokens);
    const ast = try parser.parseExpr();
    try std.testing.expect(isFuncCall(ast));
    try std.testing.expectEqualStrings(ast.func_call.id, "a");

    try std.testing.expect(isVariable(ast.func_call.*.args.items[0]));
    const expr_b = ast.func_call.*.args.items[0].*.variable;
    try std.testing.expectEqual(expr_b.token.type, TokenType.id);
    try std.testing.expectEqualStrings(expr_b.token.lexeme, "b");
    try std.testing.expectEqualStrings(expr_b.id, "b");

    try std.testing.expect(isVariable(ast.func_call.*.args.items[1]));
    const expr_c = ast.func_call.*.args.items[1].*.variable;
    try std.testing.expectEqual(expr_c.token.type, TokenType.id);
    try std.testing.expectEqualStrings(expr_c.token.lexeme, "c");
    try std.testing.expectEqualStrings(expr_c.id, "c");

    destroyParser(parser, ast);
}
