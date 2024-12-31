const std = @import("std");
const dbg = @import("./debug.zig");
const AstNode = @import("./ast_nodes.zig");
const Node = @import("./ast_nodes.zig").Node;
const BinOp = @import("./ast_nodes.zig").BinOp;
const Num = @import("./ast_nodes.zig").Num;
const TokenType = @import("./tokens.zig").TokenType;
const activeTag = std.meta.activeTag;

const NotImplented = error{NotImplemented}.NotImplemented;
const Error = error{ InterpretError, DuplicateFunctionDeclaration, MissingMainFunctionDeclaration, MismatchingBinOpTypes };

const ResultType = enum { integer, string, err };

const Result = union(ResultType) { integer: struct { val: i64 }, string: struct { val: []u8 }, err: struct { type: Error, msg: []u8 } };

pub const Interpreter = struct {
    const Self = @This();
    arena: std.heap.ArenaAllocator,
    ast: *const AstNode.Program = undefined,

    pub fn init(ast: *AstNode.Program, allocator: std.mem.Allocator) !Self {
        const arena = std.heap.ArenaAllocator.init(allocator);
        return Self{
            .ast = ast,
            .arena = arena,
        };
    }

    fn visitInteger(self: *Self, num: *Num) i64 {
        _ = self;
        return num.value;
    }

    fn visit(self: *Self, node: *const Node) anyerror!Result {
        dbg.print("\n", .{}, @src());
        switch (node.*) {
            .program => return NotImplented,
            .num => return Result{ .integer = .{ .val = self.visitInteger(node.*.num) } },
            .binop => return try self.visitBinOp(node.*.binop),
            else => return NotImplented,
        }
    }

    fn computerIntBinOp(self: *Self, binop: *const BinOp, lhs_result: Result, rhs_result: Result) !i64 {
        const lhs_val = lhs_result.integer.val;
        const rhs_val = rhs_result.integer.val;
        dbg.print("{} {s} {}\n", .{ lhs_val, binop.token.lexeme.?, rhs_val }, @src());
        var new_val: i64 = undefined;
        switch (binop.token.type) {
            TokenType.plus => new_val = lhs_result.integer.val + rhs_result.integer.val,
            TokenType.minus => new_val = lhs_result.integer.val - rhs_result.integer.val,
            TokenType.mul => new_val = lhs_result.integer.val * rhs_result.integer.val,
            TokenType.div => new_val = @divTrunc(lhs_result.integer.val, rhs_result.integer.val),
            TokenType.mod => new_val = @mod(lhs_result.integer.val, rhs_result.integer.val),
            else => return NotImplented,
        }
        _ = self;
        dbg.print("new_val == {}\n", .{new_val}, @src());
        return new_val;
    }

    fn visitBinOp(self: *Self, binop: *const BinOp) !Result {
        dbg.print("{s}\n", .{binop.token.lexeme.?}, @src());
        const lhs_result = try self.visit(binop.lhs);
        const rhs_result = try self.visit(binop.rhs);
        const lhs_res_tag = activeTag(lhs_result);
        const rhs_res_tag = activeTag(rhs_result);
        if (lhs_res_tag != rhs_res_tag) {
            return Error.MismatchingBinOpTypes;
        }
        switch (lhs_res_tag) {
            .integer => {
                return Result{ .integer = .{ .val = try self.computerIntBinOp(binop, lhs_result, rhs_result) } };
            },
            else => return NotImplented,
        }
    }

    pub fn interpret(self: *Self) !u8 {
        const functions = self.ast.functions;
        var func_ids_hashset = std.StringHashMap(void).init(self.arena.allocator());
        for (functions.items) |func| {
            switch (func.*) {
                .func_decl => {
                    const id = func.func_decl.*.id;
                    dbg.print("Function id={s}\n", .{id}, @src());
                    if (func_ids_hashset.contains(id)) {
                        return Error.DuplicateFunctionDeclaration;
                    }
                    try func_ids_hashset.put(id, {});
                },
                else => return Error.InterpretError,
            }
        }
        if (!func_ids_hashset.contains("main")) {
            return Error.MissingMainFunctionDeclaration;
        }
        dbg.print("global_len: {} ---\n", .{self.ast.global_statements.items.len}, @src());
        dbg.print("funcs_len: {} ---\n", .{self.ast.functions.items.len}, @src());
        _ = try self.visit(self.ast.functions.items[0].*.func_decl.statements.items[0]);
        // TODO: implement program return value
        return 0;
    }
};
