const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;
const AstNodes = @import("./ast_nodes.zig");
const Node = AstNodes.Node;

const Error = error{BadToken};

pub const Parser = struct {
    const Self = @This();
    tokens: []Token = undefined,
    tok_idx: usize = 0,
    allocator: std.mem.Allocator = undefined,

    pub fn init(tokens: []Token, allocator: std.mem.Allocator) !Self {
        for (tokens) |tok| {
            dbg.print("[{} \"{s}\" L:{}] ", .{ tok.type, tok.lexeme, tok.line });
        }

        const parser = Self{ .tokens = try allocator.alloc(Token, tokens.len), .allocator = allocator };
        @memcpy(parser.tokens, tokens);
        return parser;
    }

    // Utils
    fn eat(self: *Self, typ: TokenType) Error!void {
        if (self.tokens[self.tok_idx].type != typ) {
            return Error.BadToken;
        }
        self.tok_idx += 1;
    }

    fn current(self: *const Self) !Token {
        return self.tokens[self.tok_idx];
    }

    fn peek(self: *const Self, offset: usize) Token {
        return self.tokens[self.tok_idx + offset];
    }

    pub fn parse_number(self: *Self) !Node {
        dbg.print("{s} {}\n", .{ @src().fn_name, self.tok_idx });
        const token = try self.current();
        try self.eat(TokenType.number);
        const n = try std.fmt.parseFloat(f64, token.lexeme);
        // dbg.print("\n[{}]", .{n});
        return Node{ .num = try AstNodes.Num.make(AstNodes.Num{ .token = token, .value = n }, self.allocator) };
    }

    pub fn parse_factor(self: *Self) !Node {
        const node = try self.parse_number();
        // TODO: check for unary ops (plus, minus), ids and numbers
        return node;
    }
    pub fn parse_term(self: *Self) !Node {
        const node = try self.parse_factor();
        // TODO: check for binary ops tokens (mul, div)
        return node;
    }

    pub fn parse_arithmetic(self: *Self) !Node {
        var node = try self.parse_term();
        var curr = try self.current();
        while (curr.type == TokenType.plus or curr.type == TokenType.minus) {
            try self.eat(curr.type);
            const right = &(try self.parse_term());
            node = Node{ .binop = try AstNodes.BinOp.make(AstNodes.BinOp{ .token = curr, .left = &node, .right = right }, self.allocator) };
            dbg.print("{s}:{} {}\n", .{ @src().file, @src().line, self.tok_idx });
            curr = try self.current();
        }
        return node;
    }

    pub fn parse_expr(self: *Self) !Node {
        const node = try self.parse_arithmetic();
        // TODO: check for next comparison ops tokens
        return node;
    }

    pub fn parse_statement(self: *Self) !Node {
        const node = try self.parse_expr();
        // TODO: statements parsing
        return node;
    }

    pub fn visit(self: *Self, node: Node) void {
        switch (node) {
            .num => |*num| dbg.print("v{}iiictory {} \n", .{ num.*.token.type, num.*.value }),
            .binop => |*binop| {
                // _ = binop;
                dbg.print("{*}\n", .{binop.*.left});
                dbg.print("{*}\n", .{binop.*.right});
                _ = self;
                // self.visit(binop.*.left.*);
                // dbg.print(" + ", .{});
                // self.visit(binop.*.right.*);
            },
            // else => dbg.print("yo\n", .{}),
        }
    }

    pub fn parse(self: *Self) !void {
        const root_node = try self.parse_statement();
        self.visit(root_node);
        // _ = num1;
        // const num2 = try Node.Num.init(Token{ .type = TokenType.number, .lexeme = "1", .line = 1 });
        // _ = add;
    }
};
