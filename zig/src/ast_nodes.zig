const std = @import("std");
const dbg = @import("./debug.zig");
const Token = @import("./tokens.zig").Token;
const TokenType = @import("./tokens.zig").TokenType;

pub const Num = struct {
    token: Token = undefined,
    value: f64 = undefined,

    pub fn make(num: Num, allocator: std.mem.Allocator) anyerror!*Num {
        const instance = try allocator.create(Num);
        instance.* = num;
        return instance;
    }
};

pub const BinOp = struct {
    token: Token = undefined,
    left: *const Node = undefined,
    right: *const Node = undefined,

    pub fn make(binop: BinOp, allocator: std.mem.Allocator) anyerror!*BinOp {
        const instance = try allocator.create(BinOp);
        instance.* = binop;
        return instance;
    }
};

pub const Node = union(enum) { num: *Num, binop: *BinOp };
