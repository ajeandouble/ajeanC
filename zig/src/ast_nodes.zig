const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;

pub const Num = struct {
    const Self = @This();
    token: Token = undefined,
    value: i64 = undefined,

    pub fn make(num: Self, allocator: std.mem.Allocator) anyerror!*Self {
        const instance = try allocator.create(Self);
        instance.* = num;
        return instance;
    }
};

pub const BinOp = struct {
    const Self = @This();
    token: Token = undefined,
    lhs: *const Node = undefined,
    rhs: *const Node = undefined,

    pub fn make(binop: Self, allocator: std.mem.Allocator) anyerror!*Self {
        // dbg.print(
        //     "left {} right {} lexeme={s}\n",
        //     .{ binop.lhs.*, binop.rhs.*, binop.token.lexeme },
        //     @src(),
        // );
        const instance = try allocator.create(Self);
        instance.* = binop;
        return instance;
    }
};

pub const UnaryOp = struct {
    const Self = @This();
    token: Token = undefined,
    value: *const Node = undefined,

    pub fn make(unaryop: Self, allocator: std.mem.Allocator) anyerror!*Self {
        //dbg.print(
        //     "value {} lexeme={s}\n",
        //     .{ unaryop.value.*, unaryop.token.lexeme },
        //     @src(),
        // );
        const instance = try allocator.create(Self);
        instance.* = unaryop;
        return instance;
    }
};

pub const Variable = struct {
    const Self = @This();
    token: Token = undefined,
    id: []const u8,

    pub fn make(variable: Self, allocator: std.mem.Allocator) anyerror!*Self {
        dbg.print(
            "id {s} lexeme={s}\n",
            .{ variable.id, variable.token.lexeme.? },
            @src(),
        );
        const instance = try allocator.create(Self);
        instance.* = variable;
        return instance;
    }
};

pub const FunctionCall = struct {
    const Self = @This();
    token: Token = undefined,
    id: []const u8,
    args: std.ArrayList(*Node),

    pub fn make(func_call: Self, allocator: std.mem.Allocator) anyerror!*Self {
        dbg.print(
            "id {s} lexeme={s} args=..,  \n",
            .{ func_call.id, func_call.token.lexeme.? },
            @src(),
        );
        const instance = try allocator.create(Self);
        instance.* = func_call;
        return instance;
    }
};

pub const FunctionDecl = struct {
    const Self = @This();
    statements: std.ArrayList(*Node),

    pub fn make(func_decl: Self, allocator: std.mem.Allocator) anyerror!*Self {
        dbg.print(
            "id {s} lexeme={s} statements=..,  \n",
            .{ func_decl.id, func_decl.token.lexeme.? },
            @src(),
        );
        const instance = try allocator.create(Self);
        instance.* = func_decl;
        return instance;
    }
};

pub const Node = union(enum) { num: *Num, binop: *BinOp, unaryop: *UnaryOp, variable: *Variable, func_call: *FunctionCall };
