const std = @import("std");
const dbg = @import("./debug.zig");
const AstNode = @import("./ast_nodes.zig");
const Node = @import("./ast_nodes.zig").Node;

const Error = error{ InterpretError, DuplicateFunctionDeclaration, MissingMainFunctionDeclaration };

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
        // TODO: implement program return value
        return 0;
    }
};
