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
    dummy: i64 = 0,

    pub fn init(tokens: []Token, allocator: std.mem.Allocator) !Self {
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

    pub fn parse_number(self: *Self) !*Node {
        //dbg.print("{s} {}\n", .{ @src().fn_name, self.tok_idx });
        const token = try self.current();
        try self.eat(TokenType.number);
        const n = try std.fmt.parseInt(i64, token.lexeme, 10);
        dbg.print("\t\t\t\t\t{s} {}\n", .{ token.lexeme, n }, @src());
        // //dbg.print("\n[{}]", .{n});
        const num = Node{ .num = try AstNodes.Num.make(AstNodes.Num{ .token = token, .value = n }, self.allocator) };
        dbg.print("{*}{s}\n", .{ num.num, token.lexeme }, @src());
        const node = try self.allocator.create(Node);
        node.* = num;
        return node;
    }

    pub fn parse_factor(self: *Self) !*Node {
        dbg.print("\n", .{}, @src());
        const node = try self.parse_number();
        // TODO: check for unary ops (plus, minus), ids and numbers
        return node;
    }
    pub fn parse_term(self: *Self) !*Node {
        dbg.print("\n", .{}, @src());
        const node = try self.parse_factor();
        // TODO: check for binary ops tokens (mul, div)
        return node;
    }

    pub fn parse_arithmetic(self: *Self) !*Node {
        dbg.print("\n", .{}, @src());
        var node = try self.parse_term();
        var curr = try self.current();
        while (curr.type == TokenType.plus or curr.type == TokenType.minus) {
            dbg.print("{} idx={}\n", .{ curr.type, self.tok_idx }, @src());
            try self.eat(curr.type);
            const right = try self.parse_term();
            const saved_node = node;
            const node_ptr = try self.allocator.create(Node);
            node_ptr.* = Node{ .binop = try AstNodes.BinOp.make(AstNodes.BinOp{ .token = curr, .left = saved_node, .right = right }, self.allocator) };
            node = node_ptr;
            //dbg.print("{s}:{} {}\n", .{ @src().file, @src().line, self.tok_idx });
            curr = try self.current();
        }
        return node;
    }

    pub fn parse_expr(self: *Self) !*Node {
        dbg.print("\n", .{}, @src());
        const node = try self.parse_arithmetic();
        // TODO: check for next comparison ops tokens
        return node;
    }

    pub fn parse_statement(self: *Self) !*Node {
        dbg.print("\n", .{}, @src());
        const node = try self.parse_expr();
        // TODO: statements parsing
        return node;
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
                dbg.print("left\t{*}\n", .{binop.*.left}, @src());
                switch (binop.*.token.type) {
                    TokenType.plus => {
                        const l = self.visit(binop.*.left);
                        const r = self.visit(binop.*.right);
                        self.dummy += l + r;
                    },
                    else => unreachable,
                }
                dbg.print("+\n", .{}, @src());
                dbg.print("right\t{*}\n", .{binop.*.right}, @src());
                // self.visit(binop.*.right);
            },
        }
        return 0;
    }

    pub fn parse(self: *Self) !*Node {
        const root_node = try self.parse_statement();
        dbg.print("\n", .{}, @src());
        _ = self.visit(root_node);
        dbg.print("{}", .{self.dummy}, @src());
        return root_node;
        // _ = num1;
        // const num2 = try Node.Num.init(Token{ .type = TokenType.number, .lexeme = "1", .line = 1 });
        // _ = add;
    }
};

const expect = std.testing.expect;

test "parser.zig" {}
