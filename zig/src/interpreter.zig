const std = @import("std");
const Node = @import("./ast_nodes.zig");

pub const Parser = struct {
    const Self = @This();
    ast: *Node = undefined,
};

// pub fn visit(self: *Self, node: *const Node) i64 {
//     switch (node.*) {
//         .num => |*num| {
//             std.debug.print("num {} \n", .{num.*.value});
//             return num.*.value;
//             // //dbg.print("{}({})\n", .{ num.*.token.type, num.*.value }, @src());
//         },
//         .binop => |*binop| {
//             std.debug.print("binop {s} \n", .{binop.*.token.lexeme});

//             // _ = binop;
//             //dbg.print("left\t{*}\n", .{binop.*.lhs}, @src());
//             switch (binop.*.token.type) {
//                 TokenType.plus => {
//                     const l = self.visit(binop.*.lhs);
//                     const r = self.visit(binop.*.rhs);
//                 },
//                 else => unreachable,
//             }
//             //dbg.print("+\n", .{}, @src());
//             //dbg.print("right\t{*}\n", .{binop.*.rhs}, @src());
//             // self.visit(binop.*.right);
//         },
//     }
//     return 0;
// }
