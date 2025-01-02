const std = @import("std");
const dbg = @import("./debug.zig");
const AstNode = @import("./ast_nodes.zig");
const Node = @import("./ast_nodes.zig").Node;
const BinOp = @import("./ast_nodes.zig").BinOp;
const UnaryOp = @import("./ast_nodes.zig").UnaryOp;
const Num = @import("./ast_nodes.zig").Num;
const TokenType = @import("./tokens.zig").TokenType;
const activeTag = std.meta.activeTag;
const Token = @import("./tokens.zig").Token;

const NotImplented = error{NotImplemented}.NotImplemented;
const Error = error{ InterpretError, DuplicateFunctionDeclaration, MissingMainFunctionDeclaration, MismatchingBinOpTypes, InvalidGlobalStatement };

const ResultType = enum { integer, string, err, void };

const Result = union(ResultType) { integer: struct { val: i64 }, string: struct { val: []u8 }, err: struct { type: Error, msg: []u8 }, void: struct {} };
const _VariableType = enum {
    integer,
    float,
    str,
};
const _Variable = struct { type: _VariableType, str: []u8, int: i64 };

pub const StackFrame = struct {
    const Self = @This();
    locals: *std.StringHashMap(Result),

    pub fn init(allocator: std.mem.Allocator) !*Self {
        dbg.print("\n", .{}, @src());
        const stack_frame = try allocator.create(StackFrame);
        const locals = std.StringHashMap(Result).init(allocator);
        stack_frame.* = .{ .locals = locals };
        return stack_frame;
    }

    pub fn deinit(self: *Self) void {
        self.locals.deinit();
    }
};

pub const Interpreter = struct {
    const Self = @This();
    arena: std.heap.ArenaAllocator,
    stack: *std.ArrayList(StackFrame),
    ast: *const AstNode.Program = undefined,

    pub fn init(ast: *AstNode.Program, allocator: std.mem.Allocator) !Self {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const stack = try arena.allocator().create(std.ArrayList(StackFrame));
        // FIXME: ! weird behaviour, needs to alocate a lot
        stack.* = try std.ArrayList(StackFrame).initCapacity(arena.allocator(), 1024);
        return Self{ .arena = arena, .ast = ast, .stack = stack };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    // Stack
    pub fn pushStack(self: *Self) !void {
        const locals = try self.arena.allocator().create(std.StringHashMap(Result));
        locals.* = std.StringHashMap(Result).init(self.arena.allocator());
        const new_frame = StackFrame{ .locals = locals };
        try self.stack.append(new_frame);
        dbg.print("Stack: capacity = {}, length = {}\n", .{ self.stack.capacity, self.stack.items.len }, @src());
    }

    pub fn popStack(self: *Self) !void {
        // TODO: garbage collection!
        try self.stack.pop();
    }

    // Node visiting
    fn visitInteger(self: *Self, num: *Num) i64 {
        dbg.print("{}\n", .{num.value}, @src());
        _ = self;
        return num.value;
    }

    // Interpretation of funtion body
    fn visitFuncDecl(self: *Self, func_decl: *const AstNode.FunctionDecl) !Result {
        dbg.print("{s}\n", .{func_decl.id}, @src());
        try self.pushStack();
        for (func_decl.statements.items) |stmt| {
            dbg.print("\n", .{}, @src());
            _ = try self.visit(stmt);
        }
        return Result{ .integer = .{ .val = 42 } }; // FIXME: dummy return placeholder
    }

    fn visit(self: *Self, node: *const Node) anyerror!Result {
        dbg.print("\n", .{}, @src());
        switch (node.*) {
            .program => return NotImplented,
            .num => return Result{ .integer = .{ .val = self.visitInteger(node.*.num) } },
            .binop => return try self.visitBinOp(node.*.binop),
            .unaryop => return try self.visitUnaryOp(node.*.unaryop),
            .variable => {
                return NotImplented;
            },
            else => {
                return NotImplented;
            },
        }
    }

    fn computeIntBinOp(self: *Self, binop: *const BinOp, lhs_result: Result, rhs_result: Result) !i64 {
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

            TokenType.lt => new_val = @intFromBool(lhs_result.integer.val < rhs_result.integer.val),
            TokenType.le => new_val = @intFromBool(lhs_result.integer.val <= rhs_result.integer.val),
            TokenType.eq => new_val = @intFromBool(lhs_result.integer.val == rhs_result.integer.val),
            TokenType.ge => new_val = @intFromBool(lhs_result.integer.val >= rhs_result.integer.val),
            TokenType.gt => new_val = @intFromBool(lhs_result.integer.val > rhs_result.integer.val),

            else => return NotImplented,
        }
        _ = self;
        dbg.print("new_val == {}\n", .{new_val}, @src());
        return new_val;
    }

    fn visitAssignment(self: *Self, binop: *const BinOp) !void {
        dbg.print("\n", .{}, @src());
        var locals = self.stack.getLast().locals;
        const id = try self.arena.allocator().dupe(u8, binop.*.lhs.variable.id);
        const rhs_result = try self.visit(binop.rhs);
        try locals.put(id, rhs_result);
    }

    fn visitBinOp(self: *Self, binop: *const BinOp) !Result {
        dbg.print("\"{s}\"\n", .{binop.token.lexeme.?}, @src());
        if (binop.token.type == TokenType.assign) {
            try self.visitAssignment(binop);
            return Result{ .void = .{} };
        }

        const lhs_result = try self.visit(binop.lhs);
        const rhs_result = try self.visit(binop.rhs);
        const lhs_res_tag = activeTag(lhs_result);
        const rhs_res_tag = activeTag(rhs_result);
        if (lhs_res_tag != rhs_res_tag) {
            return Error.MismatchingBinOpTypes;
        }
        switch (lhs_res_tag) {
            .integer => {
                return Result{ .integer = .{ .val = try self.computeIntBinOp(binop, lhs_result, rhs_result) } };
            },
            else => return NotImplented, // NOTE: e.g. concat strings
        }
    }

    fn visitUnaryOp(self: *Self, unaryop: *const UnaryOp) !Result {
        dbg.print("'{s}'\n", .{unaryop.token.lexeme.?}, @src());
        var value_result = try self.visit(unaryop.value);
        const value_res_tag = activeTag(value_result);

        switch (value_res_tag) {
            .integer => {
                if (unaryop.token.type == TokenType.minus) {
                    value_result.integer.val = -value_result.integer.val;
                }
            },
            else => return NotImplented, // NOTE: e.g. concat strings
        }
        return value_result;
    }

    pub fn interpret(self: *Self) !u8 {
        dbg.print("\n", .{}, @src());
        const functions = self.ast.functions;
        var global_funcs = std.StringHashMap(*AstNode.FunctionDecl).init(self.arena.allocator());
        try self.pushStack();
        const global_statements = self.ast.global_statements;
        for (global_statements.items) |stmt| {
            switch (stmt.*) {
                .binop => {
                    try self.visitAssignment(stmt.*.binop);
                },
                else => return Error.InvalidGlobalStatement,
            }
        }
        for (functions.items) |func| {
            switch (func.*) {
                .func_decl => {
                    const id = func.func_decl.*.id;
                    dbg.print("Function id={s}\n", .{id}, @src());
                    if (global_funcs.contains(id)) {
                        return Error.DuplicateFunctionDeclaration;
                    }
                    try global_funcs.put(id, func.func_decl);
                },
                else => return Error.InterpretError,
            }
        }
        dbg.print("global_len: {} ---\n", .{self.ast.global_statements.items.len}, @src());
        var i: usize = 0;
        const locals = self.stack.items[0].locals;
        var it = locals.iterator();
        while (it.next()) |item| {
            dbg.print("{s}\n", .{item.key_ptr.*}, @src());
            dbg.print("{}\n", .{item.value_ptr.*}, @src());
            i += 1;
        }
        dbg.print("funcs_len: {} ---\n", .{self.ast.functions.items.len}, @src());
        _ = try self.visitFuncDecl(global_funcs.get("main") orelse return Error.MissingMainFunctionDeclaration);
        return 0;
    }
};
