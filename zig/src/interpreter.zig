const std = @import("std");
const dbg = @import("./debug.zig");
const AstNode = @import("./ast_nodes.zig");
const Node = @import("./ast_nodes.zig").Node;

const Error = error{InterpretError};

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

    pub fn interpret(self: *const Self) !u8 {
        const functions = self.ast.functions;
        for (functions.items) |func| {
            switch (func.*) {
                .func_decl => {
                    dbg.print("---{s}\n", .{func.func_decl.*.id}, @src());
                },
                else => return Error.InterpretError,
            }
        }
        dbg.print("global_len: {} ---\n", .{self.ast.global_statements.items.len}, @src());
        dbg.print("funcs_len: {} ---\n", .{self.ast.functions.items.len}, @src());
        // TODO: implement program return value
        return 0;
    }
};
