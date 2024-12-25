const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;
const AstNodes = @import("./ast_nodes.zig");
const Node = AstNodes.Node;

const NotImplemented = error{NotImplemented}.NotImplemented;

const Error = error{ ParsingError, BadToken };

pub const Parser = struct {
    const Self = @This();
    tokens: []Token = undefined,
    tok_idx: usize = 0,
    allocator: std.mem.Allocator = undefined,
    dummy: i64 = 0,

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
        if (self.tokens[self.tok_idx].type != typ) {
            return Error.BadToken;
        }
        self.tok_idx += 1;
    }

    fn current(self: *const Self) anyerror!Token {
        return self.tokens[self.tok_idx];
    }

    fn peek(self: *const Self, offset: usize) Token {
        return self.tokens[self.tok_idx + offset];
    }

    pub fn parseNumber(self: *Self) anyerror!*Node {
        const token = try self.current();
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        // dbg.print("{s} {}\n", .{ @src().fn_name, self.tok_idx });

        try self.eat(TokenType.integer);
        const n = try std.fmt.parseInt(i64, token.lexeme, 10);
        const node = try self.makeNode(Node{ .num = try AstNodes.Num.make(AstNodes.Num{ .token = token, .value = n }, self.allocator) });
        return node;
    }

    pub fn parseFactor(self: *Self) anyerror!*Node {
        const token = (try self.current());
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());

        var node: *Node = undefined;
        switch (token.type) {
            .integer => node = try self.parseNumber(),
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
        var token = try self.current();
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        var node = try self.parseFactor();

        token = try self.current();
        while (token.type == TokenType.mul or token.type == TokenType.div) {
            dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
            try self.eat(token.type);
            const rhs = try self.parseFactor();
            const lhs = node;
            const binop = try self.makeNode(Node{ .binop = try AstNodes.BinOp.make(AstNodes.BinOp{ .token = token, .lhs = lhs, .rhs = rhs }, self.allocator) });
            token = try self.current();
            node = binop;
        }
        return node;
    }

    pub fn parseArithmetic(self: *Self) anyerror!*Node {
        dbg.print("{} \"{s}\"\n", .{ (try self.current()).type, (try self.current()).lexeme }, @src());
        var node = try self.parseTerm();

        var token = try self.current();
        while (token.type == TokenType.plus or token.type == TokenType.minus) {
            dbg.print("{} idx={}\n", .{ token.type, self.tok_idx }, @src());
            try self.eat(token.type);
            const rhs = try self.parseTerm();
            const lhs = node;
            const binop = try self.makeNode(Node{ .binop = try AstNodes.BinOp.make(AstNodes.BinOp{ .token = token, .lhs = lhs, .rhs = rhs }, self.allocator) });
            node = binop;
            token = try self.current();
        }
        return node;
    }

    pub fn parseExpr(self: *Self) anyerror!*Node {
        var curr_token = (try self.current());
        dbg.print("{} \"{s}\"\n", .{ curr_token.type, curr_token.lexeme }, @src());
        var node = try self.parseArithmetic();

        while (true) {
            switch (curr_token.type) {
                .le, .lt, .eq, .ge, .gt => {
                    const saved_node = node;
                    const saved_token = curr_token;
                    try self.eat(saved_token.type);
                    curr_token = (try self.current());
                    node = try self.makeNode(Node{ .binop = try AstNodes.BinOp.make(AstNodes.BinOp{ .token = saved_token, .lhs = saved_node, .rhs = try self.parseArithmetic() }, self.allocator) });
                },
                else => break,
            }
        }
        return node;
    }

    pub fn parseStatement(self: *Self) anyerror!*Node {
        const token = (try self.current());
        dbg.print("{} \"{s}\"\n", .{ token.type, token.lexeme }, @src());
        switch (token.type) {
            .integer, .lparen, .rparen, .plus, .minus => {
                const node = try self.parseExpr();
                try self.eat(TokenType.semi);
                return node;
            },
            else => {},
        }
        // TODO: statements parsing
        return Error.ParsingError;
    }

    pub fn visit(self: *Self, node: *const Node) i64 {
        switch (node.*) {
            .num => |*num| {
                std.debug.print("num {} \n", .{num.*.value});
                return num.*.value;
                // dbg.print("{}({})\n", .{ num.*.token.type, num.*.value }, @src());
            },
            .binop => |*binop| {
                std.debug.print("binop {s} \n", .{binop.*.token.lexeme});

                // _ = binop;
                dbg.print("left\t{*}\n", .{binop.*.lhs}, @src());
                switch (binop.*.token.type) {
                    TokenType.plus => {
                        const l = self.visit(binop.*.lhs);
                        const r = self.visit(binop.*.rhs);
                        self.dummy += l + r; //FIXME: delete this
                    },
                    else => unreachable,
                }
                dbg.print("+\n", .{}, @src());
                dbg.print("right\t{*}\n", .{binop.*.rhs}, @src());
                // self.visit(binop.*.right);
            },
        }
        return 0;
    }

    pub fn parse(self: *Self) !*Node {
        const root_node = self.parseStatement() catch |err| {
            switch (err) {
                Error.BadToken => {
                    dbg.print("Bad Token: {}\n", .{(try self.current()).type}, @src());
                    return Error.ParsingError;
                },
                else => return err,
            }
        };
        dbg.print("\n", .{}, @src());
        // _ = self.visit(root_node);
        dbg.print("{}", .{self.dummy}, @src());
        return root_node;
        // _ = num1;
        // const num2 = try Node.Num.init(Token{ .type = TokenType.integer, .lexeme = "1", .line = 1 });
        // _ = add;
    }
};

const expect = std.testing.expect;

fn setupTests() !void {}
fn teardownTests() !void {}

test "parser.zig" {}
