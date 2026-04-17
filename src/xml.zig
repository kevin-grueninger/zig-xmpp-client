const std = @import("std");

const Map = std.AutoHashMap;

const Span = struct {
    start: usize,
    end: usize,
};

const Version = struct {
    major: u32,
    minor: u32,
    patch: ?u32,

    pub fn parse(string: *const []u8) !@This() {
        const slice = std.mem.splitAny(u8, string, .{"."});
        const version_ints: [2]u32 = undefined;

        for (0..2) |i| {
            const version_strs = slice.next() orelse return error.InvalidVersionString;
            std.fmt.parseInt(u32, version_ints[i], 10) orelse return error.ErrorParsingVersionString;
            version_ints[i] = version_strs;
        }
        const patch: ?u32 = undefined;
        {
            const patch_vers_string = slice.next() or null;
            if (patch_vers_string != null) {
                patch = std.fmt.parseInt(u32, &patch_vers_string, 10) orelse return error.ErrorParsingVersionString;
            }
        }

        return .{
            .major = version_ints[0],
            .minor = version_ints[1],
            .patch = patch,
        };
    }
};

fn is_space(char: u8) bool {
    return char == ' ' or char == '\n' or char == '\r';
}

fn is_closing_tag(char: u8) bool {
    return char == '>' or char == '/';
}

fn rtrim(string: *const []u8, span: Span) Span {
    while (span.start < span.end and is_space(string[span.end])) {
        --span.end;
    }
    return span;
}

fn ltrim(string: *const []u8, span: Span) Span {
    while (span.start < span.end and is_space(string[span.start])) {
        span.start += 1;
    }
    return span;
}

fn trim(string: *const []u8, span: Span) Span {
    span = rtrim(string, span.start, span.end);
    span = ltrim(string, span.start, span.end);

    return span;
}

fn next_space(string: *const []u8, span: Span) usize {
    while (span.start < span.end and !is_space(string[span.start])) {
        span.start += 1;
    }
    return span.start;
}

const ErrorType = enum {
    UnbalancedTag,
    InvalidClosingTag,
    TahHasNoData,
    TryingToParseEmpty,
};

const TagType = enum {
    Empty,
    Doctype,
    STag,
    ETag,
};

const Attribute = struct {
    name: []u8,
    value: []u8,

    pub fn format(
        this: @This(),
        writer: *std.io.Writer,
    ) !void {
        try writer.print("{s}={s}", .{ this.name, this.value });
    }
};

const Node = struct {
    parent: ?*Node,
    tag: *const []u8,
    attributes: std.ArrayList(*Attribute),
    children: std.ArrayList(*Node),
    content: ?*const []u8,

    pub fn get_child(self: @This(), name: *const []u8) ?*Node {
        for (self.children) |child| {
            if (std.mem.eql(child.name, name)) {
                return child;
            }
        }
        return null;
    }

    pub fn push_child(this: @This(), child: *@This()) !void {
        try this.children.push(child);
    }

    fn push_attribute(this: @This(), attribute: *Attribute) !void {
        try this.attributes.push(attribute);
    }

    pub fn format(this: @This(), writer: *std.io.Writer) !void {
        try writer.print("<{s} ", .{this.tag.*});

        for (this.attributes.items) |attribute| {
            try attribute.format(writer);
        }
        try writer.print(">", .{});

        for (this.children.items) |child| {
            try child.format(writer);
        }

        if (this.content != null) {
            try writer.print("{s}", .{this.content.?.*});
        }
        try writer.print("</{s}>", .{this.tag.*});
    }
};

const Tree = struct {
    doctype: []const u8 = "xml",
    xml_version: Version = .{ .major = 1, .minor = 0, .patch = null },
    root: *Node,
    nodes: std.ArrayList(Node),
    node_map: Map([]u8, *Node),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, root: *Node) @This() {
        return .{
            .root = root,
            .nodes = std.array_list.Managed(Node).init(alloc),
            .node_map = std.hash_map.AutoHashMap([]u8, *Node).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(this: @This()) void {
        this.node_map.deinit();
        this.nodes.deinit(this.alloc);
    }

    ///O(n), linear search for node with matching name
    pub fn get_node(this: *const @This(), name: *const []u8) ?Node {
        for (this.nodes.items) |node| {
            if (!std.mem.order([]u8, *node.tag, *name).differ()) {
                return &node;
            }
        }
        return null;
    }

    /// Iterate through the nodes array list, no order specified
    pub fn linear_iterator(this: *@This(), alloc: *const std.mem.Allocator) !TreeLinearIterator {
        const nodes = try alloc.alignedAlloc(*Node, std.mem.Alignment.of(*Node), this.nodes.items.len);

        for (0..this.nodes.items.len) |i| {
            nodes[i] = &this.nodes.items[i];
        }

        return .{
            .nodes = nodes,
            .ind = 0,
        };
    }

    pub fn tree_iterator(this: *@This(), alloc: std.mem.Allocator) !TreeIterator {
        return try TreeIterator.init(alloc, this.root, this.nodes.items.len);
    }
};

pub fn parse(text_to_parse: *const []u8) ?Tree {
    @as(void, text_to_parse);
    std.debug.unimplemented();
}

const TreeLinearIterator = struct {
    nodes: []*Node,
    ind: usize,

    pub fn next(this: *@This()) ?*Node {
        if (this.ind < this.nodes.len) {
            const ret = this.nodes[this.ind];
            this.ind += 1;
            return ret;
        }
        return null;
    }
};

const TreeIterator = struct {
    stack: std.ArrayListUnmanaged(*const Node) = .{},
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, root: *const Node, max_nodes: usize) !TreeIterator {
        var it: TreeIterator = .{ .alloc = alloc };
        try it.stack.ensureTotalCapacity(alloc, max_nodes);
        it.stack.appendAssumeCapacity(root);
        return it;
    }

    pub fn deinit(self: *TreeIterator) void {
        self.stack.deinit(self.alloc);
    }

    pub fn next(self: *TreeIterator) ?*const Node {
        if (self.stack.items.len == 0) return null;

        const node = self.stack.pop().?;

        // Push children in reverse to visit left-to-right.
        var i = node.children.items.len;
        while (i > 0) {
            i -= 1;
            self.stack.appendAssumeCapacity(node.children.items[i]);
        }
        return node;
    }
};

test "node :: print xml" {
    var name = "SimpleNode".*;
    var content = "Test content in here".*;
    const simpleXml: Node = .{
        .parent = null,
        .tag = &@as([]u8, &name),
        .attributes = std.ArrayList(*Attribute).empty,
        .children = std.ArrayList(*Node).empty,
        .content = &@as([]u8, &content),
    };

    std.debug.print("{f}", .{simpleXml});
}

test "tree :: linear iterator" {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var nodes: [11]Node = undefined;

    var p_name = "Parent Node".*;
    var p_content = "Some Parent Content".*;
    const parent_p = &nodes[0];
    nodes[0] = .{
        .parent = null,
        .tag = &@as([]u8, &p_name),
        .attributes = std.ArrayList(*Attribute).empty,
        .children = std.ArrayList(*Node).empty,
        .content = &@as([]u8, &p_content),
    };

    for (1..11) |i| {
        var child_name = "Child Node".*;
        var child_content = "Some Child Content".*;
        nodes[i] = .{
            .parent = parent_p,
            .tag = &@as([]u8, &child_name),
            .attributes = std.ArrayList(*Attribute).empty,
            .children = std.ArrayList(*Node).empty,
            .content = &@as([]u8, &child_content),
        };
    }

    try parent_p.children.resize(alloc, 10);
    for (1..11) |i| {
        parent_p.children.items[i - 1] = &nodes[i];
    }

    var nodes_arrlist = std.ArrayList(Node).empty;
    try nodes_arrlist.appendSlice(alloc, &nodes);
    var tree: Tree = .{
        .alloc = alloc,
        .root = parent_p,
        .nodes = nodes_arrlist,
        .node_map = undefined,
    };

    var iter = try tree.linear_iterator(&alloc);
    while (iter.next()) |node| {
        std.debug.print("{f}\n", .{node.*});
    }
}

test "tree :: tree iterator" {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var nodes: [11]Node = undefined;

    var p_name = "Parent Node".*;
    var p_content = "Some Parent Content".*;
    const parent_p = &nodes[0];
    nodes[0] = .{
        .parent = null,
        .tag = &@as([]u8, &p_name),
        .attributes = std.ArrayList(*Attribute).empty,
        .children = std.ArrayList(*Node).empty,
        .content = &@as([]u8, &p_content),
    };

    for (1..11) |i| {
        var child_name = "Child Node".*;
        var child_content = "Some Child Content".*;
        nodes[i] = .{
            .parent = parent_p,
            .tag = &@as([]u8, &child_name),
            .attributes = std.ArrayList(*Attribute).empty,
            .children = std.ArrayList(*Node).empty,
            .content = &@as([]u8, &child_content),
        };
    }

    try parent_p.children.resize(alloc, 10);
    for (1..11) |i| {
        parent_p.children.items[i - 1] = &nodes[i];
    }

    var nodes_arrlist = std.ArrayList(Node).empty;
    try nodes_arrlist.appendSlice(alloc, &nodes);
    var tree: Tree = .{ .root = parent_p, .nodes = nodes_arrlist, .node_map = undefined, .alloc = alloc };

    var iter = try tree.tree_iterator(alloc);
    while (iter.next()) |node| {
        std.debug.print("{f}\n", .{node.*});
    }
}
