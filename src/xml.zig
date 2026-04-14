const std = @import("std");

const Map = std.AutoHashMap;

const Span = struct {
    start: usize,
    end: usize,
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
    name: *const []u8,
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
        try writer.print("<{s} ", .{this.name.*});

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
        try writer.print("</{s}>", .{this.name.*});
    }
};

const Tree = struct {
    doctype: []u8 = "xml", // TODO, maybe enum better, mebe tagged enum
    xml_version: []u8 = "1.0", // TODO create struct for limited semver support

    nodes: @Vector(4, *Node),
    node_map: Map([]u8, *Node),

    pub fn get_node(this: *const @This(), name: *const []u8) ?Node {
        @as(void, this);
        @as(void, name);
        std.debug.unimplemented();
    }
};

pub fn parse(text_to_parse: *const []u8) ?Tree {
    @as(void, text_to_parse);
    std.debug.unimplemented();
}

test "print xml" {
    var name = "SimpleNode".*;
    var content = "Test content in here".*;
    const simpleXml: Node = .{
        .parent = null,
        .name = &@as([]u8, &name),
        .attributes = std.ArrayList(*Attribute).empty,
        .children = std.ArrayList(*Node).empty,
        .content = &@as([]u8, &content),
    };

    std.debug.print("{f}", .{simpleXml});
}
