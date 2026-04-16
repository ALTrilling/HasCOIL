const std = @import("std");

pub const Source = []const u8;

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
    else => @typeInfo(@TypeOf(slice)).pointer.child
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
        return .{
            .source = source
        };
    }

    fn next(self: *Tokenizer) !?Token {
        // const catchEOF = struct {
        //     fn f(val: ?u8) u8 {
        //         if (val) |val_safe| {return val_safe;} else {return null;}
        //     }
        // }.f;
        while ((slice_get(self.source, self.index) orelse {return null;}) == ' ' or (slice_get(self.source, self.index) orelse {return null;}) == '\t' or (slice_get(self.source, self.index) orelse {return null;}) == '\r' or (slice_get(self.source, self.index) orelse {return null;}) == '\n') {
            self.index += 1;
        }

        const start_index = self.index;
        return switch(slice_get(self.source, start_index).?) {
            '(' => blk: {
                    self.index += 1;
                    break :blk Token {
                        .start = start_index,
                        .end = start_index + 1,
                        .kind = Token.Kind.lparen,
                    };
                },
            ')' => blk: {
                    self.index += 1;
                    break :blk Token {
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
                break :blk Token {
                    .start = start_index,
                    .end = self.index,
                    .kind = Token.Kind.string,
                };
            },
            '0'...'9' => blk: {
                while('0' <= slice_get(self.source, self.index).? and slice_get(self.source, self.index).? <= '9') {
                    self.index += 1;
                }

                break :blk Token {
                    .start = start_index,
                    .end = self.index,
                    .kind = .{.number =
                        std.fmt.parseInt(u64, self.source.*[start_index..self.index], 10) catch {return error.InvalidIntLiteral;}
                    },
                };
            },
            ':' => blk: {
                self.index += 1;
                while((('a' <= slice_get(self.source, self.index).? and slice_get(self.source, self.index).? <= 'z'))
                    or (('A' <= slice_get(self.source, self.index).? and slice_get(self.source, self.index).? <= 'Z'))
                    or slice_get(self.source, self.index).? == '_') {
                    self.index += 1;
                }

                break :blk Token {
                    .start = start_index,
                    .end = self.index,
                    .kind = Token.Kind.identifier,
                };

            },
            else => error.UnknownSymbol
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
        const test_token_kinds = [_]Token.Kind{.lparen, .identifier, .{.number = 10}, .lparen, .string, .string, .rparen, .rparen};
        const test_string_reprs = [_][]const u8{"(", ":identifier", "10", "(", "\"string\"", "\"test_with_\\\"escape\\\"\"", ")", ")"};
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
}