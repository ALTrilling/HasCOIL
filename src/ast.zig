const std = @import("std");

pub const Source = []const u8;
const eval = @import("eval.zig");

pub const Token = struct {
    start: u32,
    end: u32,
    kind: Kind,

    pub const Kind = union(enum) {
        rparen,
        lparen,
        identifier,
        string,
        number: u64,
    };
};

pub fn slice_get(slice: anytype, index: usize) ?(switch (@typeInfo(@typeInfo(@TypeOf(slice)).pointer.child)) {
    .pointer => |contained| contained.child,
    else => @typeInfo(@TypeOf(slice)).pointer.child,
}) {
    switch (@typeInfo(@typeInfo(@TypeOf(slice)).pointer.child)) {
        .pointer => {
            if (index < slice.len) {
                return slice.*[index];
            } else {
                return null;
            }
        },
        else => {
            if (index < slice.len) {
                return slice[index];
            } else {
                return null;
            }
        },
    }
}

test "Slice Get Functionality" {
    var test_string: []const u8 = "abcdefghijklmnopqrstuvwxyz";
    try std.testing.expectEqual('a', slice_get(test_string, 0));
    try std.testing.expectEqual('z', slice_get(test_string, 25));
    try std.testing.expectEqual('a', slice_get(&test_string, 0));
    try std.testing.expectEqual('z', slice_get(&test_string, 25));
    try std.testing.expectEqual(null, slice_get(test_string, 26));
    try std.testing.expectEqual(null, slice_get(test_string, 260));
    try std.testing.expectEqual(null, slice_get(&test_string, 26));
    try std.testing.expectEqual(null, slice_get(&test_string, 260));
}

pub const Tokenizer = struct {
    source: *Source,
    index: u32 = 0,

    pub fn init(source: *Source) Tokenizer {
        return .{ .source = source };
    }

    fn next(self: *Tokenizer) !?Token {
        // const catchEOF = struct {
        //     fn f(val: ?u8) u8 {
        //         if (val) |val_safe| {return val_safe;} else {return null;}
        //     }
        // }.f;
        while ((slice_get(self.source, self.index) orelse {
            return null;
        }) == ' ' or (slice_get(self.source, self.index) orelse {
            return null;
        }) == '\t' or (slice_get(self.source, self.index) orelse {
            return null;
        }) == '\r' or (slice_get(self.source, self.index) orelse {
            return null;
        }) == '\n') {
            self.index += 1;
        }

        const start_index = self.index;
        return switch (slice_get(self.source, start_index).?) {
            '(' => blk: {
                self.index += 1;
                break :blk Token{
                    .start = start_index,
                    .end = start_index + 1,
                    .kind = Token.Kind.lparen,
                };
            },
            ')' => blk: {
                self.index += 1;
                break :blk Token{
                    .start = start_index,
                    .end = start_index + 1,
                    .kind = Token.Kind.rparen,
                };
            },
            '"' => blk: {
                self.index += 1;
                var next_escaped = false;
                while (true) {
                    if (next_escaped == false and slice_get(self.source, self.index).? == '"') break;
                    next_escaped = false;
                    self.index += 1;
                    if (slice_get(self.source, self.index - 1).? == '\\') next_escaped = true;
                }
                self.index += 1;
                break :blk Token{
                    .start = start_index,
                    .end = self.index,
                    .kind = Token.Kind.string,
                };
            },
            '0'...'9' => blk: {
                while ('0' <= slice_get(self.source, self.index).? and slice_get(self.source, self.index).? <= '9') {
                    self.index += 1;
                }

                break :blk Token{
                    .start = start_index,
                    .end = self.index,
                    .kind = .{ .number = std.fmt.parseInt(u64, self.source.*[start_index..self.index], 10) catch {
                        return error.InvalidIntLiteral;
                    } },
                };
            },
            else => blk: {
                self.index += 1;
                // use `man ascii` to view the character range
                // Only following printing ascii characters are not permitted ! " # $ % & ' ( )
                while (('*' <= slice_get(self.source, self.index).? and slice_get(self.source, self.index).? <= '~')) {
                    self.index += 1;
                }

                break :blk Token{
                    .start = start_index,
                    .end = self.index,
                    .kind = Token.Kind.identifier,
                };
            },
        };
    }
};

test "Tokenizer" {
    // const alloc = std.testing.allocator;
    // {
    //     // Run until error. We don't really have errors yet but fun that its possible
    //     const test_string = "((())";
    //     var tokenizer: Tokenizer = .init(test_string);
    //     const parse_result = blk: {while (true) {
    //         if (tokenizer.next(alloc)) |_| {} else |err| {
    //             break :blk err;
    //         }
    //     }};
    // }
    {
        var test_string: []const u8 = "(:identifier 10 (\"string\" \"test_with_\\\"escape\\\"\"))";
        const test_token_kinds = [_]Token.Kind{ .lparen, .identifier, .{ .number = 10 }, .lparen, .string, .string, .rparen, .rparen };
        const test_string_reprs = [_][]const u8{ "(", ":identifier", "10", "(", "\"string\"", "\"test_with_\\\"escape\\\"\"", ")", ")" };
        var tokenizer: Tokenizer = .init(&test_string);
        var i: u32 = 0;
        while (true) : (i += 1) {
            const token = try tokenizer.next() orelse {
                // std.debug.print("EOF found\n", .{});
                break;
            };
            // {
            //     std.debug.print("Current index: {d}, current token: {any}\n", .{i, token});
            //     std.debug.print("String representation: {s}\n", .{test_string[token.start..token.end]});
            // }
            try std.testing.expectEqual(test_token_kinds[i], token.kind);
            try std.testing.expectEqualStrings(test_string[token.start..token.end], test_string_reprs[i]);
        }
    }
    // Multi-line testing
    {
        var test_string: []const u8 = "(:ident\n\t:ifier 1\n\t\t0)\n(:FunctionCall\n\t1000)";
        const test_token_kinds = [_]Token.Kind{ .lparen, .identifier, .identifier, .{ .number = 1 }, .{ .number = 0 }, .rparen, .lparen, .identifier, .{ .number = 1000 }, .rparen };
        const test_string_reprs = [_][]const u8{ "(", ":ident", ":ifier", "1", "0", ")", "(", ":FunctionCall", "1000", ")" };
        var tokenizer: Tokenizer = .init(&test_string);
        var i: u32 = 0;
        while (true) : (i += 1) {
            const token = try tokenizer.next() orelse {
                // std.debug.print("EOF found\n", .{});
                break;
            };
            // {
            //     std.debug.print("Current index: {d}, current token: {any}\n", .{i, token});
            //     std.debug.print("String representation: {s}\n", .{test_string[token.start..token.end]});
            // }
            try std.testing.expectEqual(test_token_kinds[i], token.kind);
            try std.testing.expectEqualStrings(test_string[token.start..token.end], test_string_reprs[i]);
        }
    }
    // Weird looking but still technically correct testing
    {
        var test_string: []const u8 = "(                 1000           )\n(:awa50owo)";
        const test_token_kinds = [_]Token.Kind{ .lparen, .{ .number = 1000 }, .rparen, .lparen, .identifier, .rparen };
        const test_string_reprs = [_][]const u8{ "(", "1000", ")", "(", ":awa50owo", ")" };
        var tokenizer: Tokenizer = .init(&test_string);
        var i: u32 = 0;
        while (true) : (i += 1) {
            const token = try tokenizer.next() orelse {
                // std.debug.print("EOF found\n", .{});
                break;
            };
            // {
            //     std.debug.print("Current index: {d}, current token: {any}\n", .{i, token});
            //     std.debug.print("String representation: {s}\n", .{test_string[token.start..token.end]});
            // }
            try std.testing.expectEqual(test_token_kinds[i], token.kind);
            try std.testing.expectEqualStrings(test_string_reprs[i], test_string[token.start..token.end]);
        }
    }
}

/// Make a list expression.
/// If `initial_expressions` is not null, each item is added
pub fn make_list_expr(initial_expressions: ?[]const *ExprValue, allocator: std.mem.Allocator) !*ExprValue {
    var expr = try allocator.create(ExprValue);
    expr.* = ExprValue{ .lst = try std.ArrayList(*ExprValue).initCapacity(allocator, 0) };
    if (initial_expressions) |expressions| {
        for (expressions) |e| {
            try expr.lst.append(allocator, e);
        }
    }
    return expr;
}

pub const Parser = struct {
    source: Source,
    curr: *ExprValue = undefined,
    allocator: std.mem.Allocator,
    list_stack: std.ArrayList(*ExprValue),

    pub fn init(source: Source, allocator: std.mem.Allocator) !Parser {
        return .{ .source = source, .allocator = allocator, .list_stack = try std.ArrayList(*ExprValue).initCapacity(allocator, 8) };
    }

    pub fn deinit(self: *Parser) void {
        for (self.curr.lst.items) |e| {
            e.deinit(self.allocator);
        }
        self.curr.lst.deinit(self.allocator);
        self.allocator.destroy(self.curr);
        for (self.list_stack.items) |e| {
            e.deinit(self.allocator);
        }
        self.list_stack.deinit(self.allocator);
    }

    pub fn parse(self: *Parser) !std.ArrayList(*ExprValue) {
        self.curr = try make_list_expr(null, self.allocator);
        // try self.list_stack.append(self.allocator, self.curr);
        var tokenizer: Tokenizer = .init(&self.source);
        while (try tokenizer.next()) |token| {
            switch (token.kind) {
                .lparen => {
                    try self.list_stack.append(self.allocator, self.curr);
                    self.curr = try make_list_expr(null, self.allocator);
                },
                .rparen => {
                    if (self.list_stack.items.len == 0) {
                        return error.TooManyRparens;
                    }
                    const completed_list = self.curr;
                    self.curr = self.list_stack.pop().?;
                    std.debug.assert(self.curr.* == .lst);
                    try self.curr.lst.append(self.allocator, completed_list);
                },
                .identifier => {
                    const expr = try self.allocator.create(ExprValue);
                    expr.* = ExprValue{ .iden = .{ .start = token.start, .end = token.end } };
                    try self.curr.lst.append(self.allocator, expr);
                },
                .string => {},
                .number => |num| {
                    _ = num;
                },
            }
        }
        return self.curr.lst;
    }
};

pub const ExprValue = union(enum) {
    num: u64, // Might not implement
    str: struct { start: u32, end: u32 }, // Might not implement
    iden: struct { start: u32, end: u32 },
    lst: std.ArrayList(*ExprValue),

    pub fn deinit(self: *ExprValue, allocator: std.mem.Allocator) void {
        if (std.meta.activeTag(self.*) == .lst) {
            for (self.lst.items) |e| {
                e.deinit(allocator);
            }
            self.lst.deinit(allocator);
        }
        allocator.destroy(self);
    }

    pub fn format(
        self: ExprValue,
        source: []const u8,
        writer: *std.Io.Writer,
        max_chars: u32,
    ) !void {
        var char_count: u32 = 0;
        try self.internal_format(0, source, writer, &char_count, max_chars);
        try writer.writeByte('\n');
    }

    fn internal_format(self: ExprValue, indenting: u32, source: []const u8, writer: *std.Io.Writer, char_count: *u32, max_chars: u32) !void {
        switch (self) {
            .num => {
                try writer.print("{d}", .{self.num});
            },
            .str => {
                _ = try writer.write(source[self.str.start..self.str.end]);
            },
            .iden => {
                const iden_length = self.iden.end - self.iden.start;
                if (char_count.* + iden_length > max_chars) {
                    try writer.writeByte('\n');
                    for (0..indenting * 2) |_| {
                        try writer.writeByte(' ');
                    }
                    char_count.* = 0;
                }
                _ = try writer.write(source[self.iden.start..self.iden.end]);
                char_count.* = char_count.* + iden_length;
            },
            .lst => {
                // try writer.writeByte('\n');
                // for(0..indenting) |_| {
                //     try writer.writeByte('\t');
                // }

                try writer.writeByte('(');
                // try writer.writeByte('\n');
                // for(0..indenting+1) |_| {
                //     try writer.writeByte('\t');
                // }
                for (self.lst.items, 0..) |e, i| {
                    try e.internal_format(indenting + 1, source, writer, char_count, max_chars);
                    if (i != self.lst.items.len - 1) {
                        try writer.writeByte(' ');
                        char_count.* += 1;
                    }
                }

                // try writer.writeByte('\n');
                // for(0..indenting*2) |_| {
                //     try writer.writeByte(' ');
                // }

                _ = try writer.write(")");
            },
        }
    }
};

const InspectExprIdent = struct {
    inline fn f(test_string: *const []const u8, parsed_result: std.ArrayList(*ExprValue), path: anytype) []const u8 {
        if (@typeInfo(@TypeOf(path)) != .@"struct") {
            @compileError("Must pass in a tuple");
        }
        var curr: *ExprValue = parsed_result.items[@field(path, std.meta.fields(@TypeOf(path))[0].name)];
        inline for (std.meta.fields(@TypeOf(path))[1..]) |field| {
            curr = curr.lst.items[@field(path, field.name)];
        }
        return test_string.*[curr.iden.start..curr.iden.end];
    }
}.f;

test "Parser" {
    const allocator = std.testing.allocator;
    {
        const test_string: []const u8 = "(:function :arg1 :arg2)";
        var parser = try Parser.init(test_string, allocator);
        const parsed_result = try parser.parse();
        defer parser.deinit();

        try std.testing.expectEqualDeep(1, parsed_result.items.len);

        // try std.testing.expectEqualDeep(":function", test_string_1[parsed_result.items[0].lst.items[0].iden.start..parsed_result.items[0].lst.items[0].iden.end]);
        try std.testing.expectEqualDeep(":function", InspectExprIdent(&test_string, parsed_result, .{ 0, 0 }));

        // try std.testing.expectEqualDeep(":arg1", test_string[parsed_result.items[0].lst.items[1].iden.start..parsed_result.items[0].lst.items[1].iden.end]);
        try std.testing.expectEqualDeep(":arg1", InspectExprIdent(&test_string, parsed_result, .{ 0, 1 }));

        // try std.testing.expectEqualDeep(":arg2", test_string[parsed_result.items[0].lst.items[2].iden.start..parsed_result.items[0].lst.items[2].iden.end]);
        try std.testing.expectEqualDeep(":arg2", InspectExprIdent(&test_string, parsed_result, .{ 0, 2 }));
    }

    {
        const test_string: []const u8 = "(:function1 :x (:function2 :z :w) :y)\n\t(:function3 :a)";
        var parser = try Parser.init(test_string, allocator);
        const parsed_result = try parser.parse();
        defer parser.deinit();

        try std.testing.expectEqual(2, parsed_result.items.len);
        try std.testing.expectEqualStrings(":function1", InspectExprIdent(&test_string, parsed_result, .{ 0, 0 }));
        try std.testing.expectEqualStrings(":x", InspectExprIdent(&test_string, parsed_result, .{ 0, 1 }));
        try std.testing.expectEqualStrings(":function2", InspectExprIdent(&test_string, parsed_result, .{ 0, 2, 0 }));
        try std.testing.expectEqualStrings(":z", InspectExprIdent(&test_string, parsed_result, .{ 0, 2, 1 }));
        try std.testing.expectEqualStrings(":w", InspectExprIdent(&test_string, parsed_result, .{ 0, 2, 2 }));
        try std.testing.expectEqualStrings(":y", InspectExprIdent(&test_string, parsed_result, .{ 0, 3 }));
        try std.testing.expectEqualStrings(":function3", InspectExprIdent(&test_string, parsed_result, .{ 1, 0 }));
        try std.testing.expectEqualStrings(":a", InspectExprIdent(&test_string, parsed_result, .{ 1, 1 }));
    }
}

var var_counter_index: u32 = 0;

// Zig version of var_counter_index++
fn next_index() u32 {
    const index = var_counter_index;
    var_counter_index += 1;
    return index;
}

pub fn ast_to_graph(source: *Source, ast: std.ArrayList(*ExprValue), allocator: std.mem.Allocator) !eval.Book {
    var book: eval.Book = try .init(allocator, &[_]eval.Rdx{}, &[_]void{}, allocator);
    const new: eval.GraphStateContainer = .init(&book);
    for (ast.items) |expr| {
        graphify(source, expr, new); // Each unique top level expression will generate a disjoint graph
    }
}

// Graphify meaning "turn into a graph"
pub fn graphify(source: *Source, expr: *ExprValue, new: eval.GraphStateContainer) !.{ eval.Term, eval.Pos.Var } {
    if (expr == .lst and expr.lst.items[0] == .iden) {
        const iden_val = source.*[expr.lst.items[0].iden.start..expr.lst.items[0].iden.end];
        if (std.mem.eql(u8, iden_val, "@") or std.mem.eql(u8, iden_val, ":apply")) {
            return graphify_application_sexpr(source, expr, new);
        } else if (std.mem.eql(u8, iden_val, "/") or std.mem.eql(u8, iden_val, ":lambda")) {
            return graphify_abstraction_sexpr(source, expr, new)[0];
        } else if (std.mem.eql(u8, iden_val, ":sup")) {
            return graphify_sup_sexpr(source, expr, new);
        } else {
            return error.unknownNodeConstructorName;
        }
    } else {
        return error.mustStartWithNodeDefSExpr;
    }
}
pub fn graphify_pos(source: *Source, expr: *ExprValue, new: eval.GraphStateContainer) !.{ eval.Pos, eval.Neg.Sub } {
    if (expr == .lst and expr.lst.items[0] == .iden) {
        const iden_val = source.*[expr.lst.items[0].iden.start..expr.lst.items[0].iden.end];
        if (std.mem.eql(u8, iden_val, "/") or std.mem.eql(u8, iden_val, ":lambda")) {
            return graphify_abstraction_sexpr(source, expr, new)[0];
        } else if (std.mem.eql(u8, iden_val, ":sup")) {
            return graphify_sup_sexpr(source, expr, new);
        } else {
            return error.unknownNodeConstructorName;
        }
    } else {
        return error.mustStartWithNodeDefSExpr;
    }
}

pub fn graphify_neg(source: *Source, expr: *ExprValue, new: eval.GraphStateContainer) !.{ eval.Neg, eval.Pos.Var } {
    @panic("");
}

// Returns the node and the outgoing return id ()
pub fn graphify_application_sexpr(source: *Source, expr: *ExprValue, new: eval.GraphStateContainer) !.{eval.Pos.Lam, eval.Neg.Sub } {
    const function = graphify_pos(source, expr.lst[1], new);
    const argument = graphify(source, expr.lst[2], new);
    const argument_result = argument[1];

    const return_index = next_index();
    const application = try new.App(argument_result, new.Var(return_index));

    try .{new.Redex(function, application), return_index};
}

pub fn graphify_abstraction_sexpr(source: *Source, expr: *ExprValue, new: eval.GraphStateContainer) !.{eval.Pos.Lam, eval.Neg.Sub } {
    const bnd = new.Sub(0);
    const bod = graphify_neg(expr.lst[2]);
    const abstraction = try new.Lam(bnd, bod); // bnd
}
