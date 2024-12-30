const std = @import("std");
const Node = @import("./ast_nodes.zig");

pub const Parser = struct {
    const Self = @This(),
    const ast = *Node;
