const std = @import("std");
const dbg = @import("./debug.zig");
const AstNode = @import("./ast_nodes.zig");
const Node = @import("./ast_nodes.zig").Node;
const Program = @import("./ast_nodes.zig").Program;
const FunctionDecl = @import("./ast_nodes.zig").FunctionDecl;
const BinOp = @import("./ast_nodes.zig").BinOp;
const UnaryOp = @import("./ast_nodes.zig").UnaryOp;
const Num = @import("./ast_nodes.zig").Num;
const Variable = @import("./ast_nodes.zig").Variable;
const FunctionCall = @import("./ast_nodes.zig").FunctionCall;
const TokenType = @import("./tokens.zig").TokenType;
const Token = @import("./tokens.zig").Token;
const activeTag = std.meta.activeTag;

const NotImplented = error{NotImplemented}.NotImplemented;
const Error = error{ InterpretError, DuplicateFunctionDeclaration, MissingMainFunctionDeclaration, MismatchingBinOpTypes, InvalidGlobalStatement, VariableIsNotDeclared };

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
    symbols: std.StringHashMap(Result),

    pub fn init(allocator: std.mem.Allocator) !Self {
        dbg.print("\n", .{}, @src());
        const locals = std.StringHashMap(Result).init(allocator);
        return Self{ .symbols = locals };
    }

    pub fn deinit(self: *Self) void {
        self.symbols.deinit();
    }
};

pub const Interpreter = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    stack: std.ArrayList(StackFrame),
    global_funcs: std.StringHashMap(*FunctionDecl),
    ast: *const Program = undefined,

    pub fn init(ast: *Program, allocator: std.mem.Allocator) !Self {
        const stack = try std.ArrayList(StackFrame).initCapacity(allocator, 1024);
        const global_funcs = std.StringHashMap(*FunctionDecl).init(allocator);
        return Self{ .allocator = allocator, .ast = ast, .stack = stack, .global_funcs = global_funcs };
    }

    pub fn deinit(self: *Self) void {
        self.stack.deinit();
        self.global_funcs.deinit();
    }

    // Stack
    pub fn pushStack(self: *Self) !void {
        dbg.print("Stack: capacity = {}, length = {}\n", .{ self.stack.capacity, self.stack.items.len }, @src());
        const frame = try StackFrame.init(self.allocator);
        try self.stack.append(frame);
    }

    pub fn popStack(self: *Self) !void {
        dbg.print("\n", .{}, @src());
        const frame = &self.stack.getLast();
        var it = frame.symbols.iterator();
        while (it.next()) |item| {
            dbg.print("{s}\n", .{item.key_ptr.*}, @src());
            dbg.print("{}\n", .{item.value_ptr.*}, @src());
        }
        _ = self.stack.pop();
    }

    // Node visiting
    fn visitInteger(self: *Self, num: *Num) i64 {
        dbg.print("{}\n", .{num.value}, @src());
        _ = self;
        return num.value;
    }

    // Interpretation of funtion body
    fn visitFuncDecl(self: *Self, func_decl: *const FunctionDecl) !Result {
        dbg.print("{s}\n", .{func_decl.id}, @src());
        try self.pushStack();
        for (func_decl.statements.items) |stmt| {
            dbg.print("\n", .{}, @src());
            _ = try self.visit(stmt);
        }
        try self.popStack();
        return Result{ .integer = .{ .val = 42 } }; // FIXME: dummy return placeholder
    }

    fn visitVariable(self: *Self, node: *const Variable) !Result {
        dbg.print("variable id={s}\n", .{node.id}, @src());
        var locals = self.stack.getLast().symbols;
        if (locals.get(node.id)) |value| {
            return Result{ .integer = .{ .val = value.integer.val } };
        } else {
            return Error.VariableIsNotDeclared;
        }
    }

    fn visitFuncCall(self: *Self, node: *const FunctionCall) !Result {
        const id = node.id;
        if (self.global_funcs.get(id)) |value| {
            return self.visitFuncDecl(value);
        } else {
            return Error.VariableIsNotDeclared;
        }
    }
    fn visit(self: *Self, node: *const Node) anyerror!Result {
        dbg.print("\n", .{}, @src());
        switch (node.*) {
            .program => return NotImplented,
            .num => return Result{ .integer = .{ .val = self.visitInteger(node.*.num) } },
            .binop => return try self.visitBinOp(node.*.binop),
            .unaryop => return try self.visitUnaryOp(node.*.unaryop),
            .variable => return try self.visitVariable(node.*.variable),
            .func_call => return try self.visitFuncCall(node.*.func_call),
            else => {
                return NotImplented;
            },
        }
    }

    fn computeIntBinOp(self: *Self, binop: *const BinOp, lhs_result: Result, rhs_result: Result) !i64 {
        const lhs_val = lhs_result.integer.val;
        const rhs_val = rhs_result.integer.val;
        dbg.print("{} {} {}\n", .{ lhs_val, binop.token.type, rhs_val }, @src());
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
        var locals = self.stack.getLast().symbols;
        const id = try self.allocator.dupe(u8, binop.*.lhs.variable.id);
        const rhs_result = try self.visit(binop.rhs);
        try locals.put(id, rhs_result);
        var it = locals.iterator();
        while (it.next()) |item| {
            dbg.print("{s}\n", .{item.key_ptr.*}, @src());
            dbg.print("{}\n", .{item.value_ptr.*}, @src());
        }
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
        const global_statements = self.ast.global_statements;
        for (global_statements.items) |stmt| {
            switch (stmt.*) {
                .binop => {
                    try self.visitAssignment(stmt.*.binop);
                },
                else => return Error.InvalidGlobalStatement,
            }
        }
        dbg.print("funcs_len: {}\n", .{self.ast.functions.items.len}, @src());
        for (functions.items) |func| {
            switch (func.*) {
                .func_decl => {
                    const decl = func.func_decl;
                    const id = func.func_decl.*.id;
                    dbg.print("Function id={s}\n", .{id}, @src());
                    if (self.global_funcs.contains(id)) {
                        return Error.DuplicateFunctionDeclaration;
                    }
                    const key = try self.allocator.dupe(u8, func.func_decl.id);
                    dbg.print("{s}\n", .{func.func_decl.id}, @src());
                    try self.global_funcs.put(key, decl);
                },
                else => return Error.InterpretError,
            }
        }
        dbg.print("global_len: {}\n", .{self.ast.global_statements.items.len}, @src());
        var i: usize = 0;
        try self.pushStack();
        const global_symbols = self.stack.items[0].symbols;
        var it = global_symbols.iterator();
        while (it.next()) |item| {
            dbg.print("{s}\n", .{item.key_ptr.*}, @src());
            dbg.print("{}\n", .{item.value_ptr.*}, @src());
            i += 1;
        }
        // dbg.print("funcs_len: {} ---\n", .{self.ast.functions.items.len}, @src());
        _ = try self.visitFuncDecl(self.global_funcs.get("main") orelse return Error.MissingMainFunctionDeclaration);
        return 0;
    }
};
