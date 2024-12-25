const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;

pub const Num = struct {
    token: Token = undefined,
    value: i64 = undefined,

    pub fn make(num: Num, allocator: std.mem.Allocator) anyerror!*Num {
        const instance = try allocator.create(Num);
        instance.* = num;
        return instance;
    }
};

pub const BinOp = struct {
    token: Token = undefined,
    lhs: *const Node = undefined,
    rhs: *const Node = undefined,

    pub fn make(binop: BinOp, allocator: std.mem.Allocator) anyerror!*BinOp {
        dbg.print(
            "left {} right {} lexeme={s}\n",
            .{ binop.lhs.*, binop.rhs.*, binop.token.lexeme },
            @src(),
        );
        const instance = try allocator.create(BinOp);
        instance.* = binop;
        return instance;
    }
};

pub const UnaryOp = struct {
    const Self = @This();
    token: Token = undefined,
    value: *const Node = undefined,

    pub fn make(unaryop: Self, allocator: std.mem.Allocator) anyerror!*UnaryOp {
        dbg.print(
            "value {} lexeme={s}\n",
            .{ unaryop.value.*, unaryop.token.lexeme },
            @src(),
        );
        const instance = try allocator.create(UnaryOp);
        instance.* = unaryop;
        return instance;
    }
};

pub const Node = union(enum) { num: *Num, binop: *BinOp, unaryop: *UnaryOp };
