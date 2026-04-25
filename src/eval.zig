const std = @import("std");

pub const Name = u32;

pub const Tag = enum(u8) { Var, Nil, Lam, Sup, Sub, Era, App, Dup };

pub const Term = union(enum) { Pos: *Pos, Neg: *Neg };

pub const Rdx = struct {
    neg: *Neg,
    pos: *Pos,
};

pub const Book = std.AutoArrayHashMapUnmanaged(Rdx, void);
pub const Vars = std.AutoHashMap(Name, *Pos);
pub const Subs = std.AutoHashMap(Name, *Neg);

pub const Pos = union(enum) {
    // Variable
    Var: struct { nam: Name },
    // Delete information (basically an eraser node afaict, just with reversed polarity)
    Nil: struct {},
    // Lambda
    Lam: struct {
        bnd: *Neg,
        bod: *Pos,
    },
    // Superposition
    Sup: struct {
        sp0: *Pos,
        sp1: *Pos,
    },

    pub fn deinit(self: *Pos, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .Var, .Nil => {},
            .Lam => |*l| {
                l.bnd.deinit(alloc);
                l.bod.deinit(alloc);
            },
            .Sup => |*s| {
                s.sp0.deinit(alloc);
                s.sp1.deinit(alloc);
            },
        }
        alloc.destroy(self);
    }
};

pub const Neg = union(enum) {
    // Substitution. Inverse of variable
    Sub: struct { nam: Name },
    // Delete information
    Era: struct {},
    // Application. Inverse of lambda.
    App: struct {
        arg: *Pos,
        ret: *Neg,
    },
    // Duplication
    Dup: struct {
        dp0: *Neg,
        dp1: *Neg,
    },

    pub fn deinit(self: *Neg, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .Sub, .Era => {},
            .App => |*a| {
                a.arg.deinit(alloc);
                a.ret.deinit(alloc);
            },
            .Dup => |*d| {
                d.dp0.deinit(alloc);
                d.dp1.deinit(alloc);
            },
        }
        alloc.destroy(self);
    }
};

var global_name: Name = 0;

fn wire(alloc: std.mem.Allocator) !struct { @"0": *Neg, @"1": *Pos } {
    const x = global_name;
    global_name += 1;
    const neg = try alloc.create(Neg);
    neg.* = .{ .Sub = .{ .nam = x } };
    const pos = try alloc.create(Pos);
    pos.* = .{ .Var = .{ .nam = x } };
    return .{ .@"0" = neg, .@"1" = pos };
}

pub fn show(term: Term, vars: *Vars, subs: *Subs, alloc: std.mem.Allocator) ![]const u8 {
    switch (term) {
        .Pos => {
            switch (term.Pos.*) {
                .Var => {
                    const name = vars.get(term.Pos.Var.nam);
                    if (name == null) {
                        return try std.fmt.allocPrint(alloc, "+{d}", .{term.Pos.Var.nam});
                    } else {
                        return try show(.{ .Pos = name.? }, vars, subs, alloc);
                    }
                },
                .Nil => {
                    return "+_";
                },
                .Lam => {
                    const bnd_fmt = try show(.{ .Neg = term.Pos.Lam.bnd }, vars, subs, alloc);
                    defer alloc.free(bnd_fmt);
                    const bod_fmt = try show(.{ .Pos = term.Pos.Lam.bod }, vars, subs, alloc);
                    defer alloc.free(bod_fmt);
                    return try std.fmt.allocPrint(alloc, "+({s} {s})", .{ bnd_fmt, bod_fmt });
                },
                .Sup => {
                    const sp0_fmt = try show(.{ .Pos = term.Pos.Sup.sp0 }, vars, subs, alloc);
                    defer alloc.free(sp0_fmt);
                    const sp1_fmt = try show(.{ .Pos = term.Pos.Sup.sp1 }, vars, subs, alloc);
                    defer alloc.free(sp1_fmt);
                    return try std.fmt.allocPrint(alloc, "+{{{s} {s}}}", .{ sp0_fmt, sp1_fmt });
                },
            }
        },
        .Neg => {
            switch (term.Neg.*) {
                .Sub => {
                    const name = vars.get(term.Neg.Sub.nam);
                    if (name == null) {
                        return try std.fmt.allocPrint(alloc, "-{d}", .{term.Neg.Sub.nam});
                    } else {
                        return try show(.{ .Pos = name.? }, vars, subs, alloc);
                    }
                },
                .Era => {
                    return "-_";
                },
                .App => {
                    const arg_fmt = try show(.{ .Pos = term.Neg.App.arg }, vars, subs, alloc);
                    defer alloc.free(arg_fmt);
                    const ret_fmt = try show(.{ .Neg = term.Neg.App.ret }, vars, subs, alloc);
                    defer alloc.free(ret_fmt);
                    return try std.fmt.allocPrint(alloc, "-({s} {s})", .{ arg_fmt, ret_fmt });
                },
                .Dup => {
                    const dp0_fmt = try show(.{ .Neg = term.Neg.Dup.dp0 }, vars, subs, alloc);
                    defer alloc.free(dp0_fmt);
                    const dp1_fmt = try show(.{ .Neg = term.Neg.Dup.dp1 }, vars, subs, alloc);
                    defer alloc.free(dp1_fmt);
                    return try std.fmt.allocPrint(alloc, "-{{{s} {s}}}", .{ dp0_fmt, dp1_fmt });
                },
            }
        },
    }
}

// def show(term: Term, vars: dict[Name, Pos] = {}, subs: dict[Name, Neg] = {}) -> str:
//     match term:
//         case Var(nam):
//             if nam in vars:
//                 return f"{show(vars[nam], vars, subs)}"
//             else:
//                 return f"+{nam}"
//         case Sub(nam):
//             if nam in subs:
//                 return f"{show(subs[nam], vars, subs)}"
//             else:
//                 return f"-{nam}"
//         case Nil():
//             return f"+_"
//         case Era():
//             return f"-_"
//         case Lam(bnd, bod):
//             return f"+({show(bnd, vars, subs)} {show(bod, vars, subs)})"
//         case App(arg, ret):
//             return f"-({show(arg, vars, subs)} {show(ret, vars, subs)})"
//         case Dup(dp0, dp1):
//             return f"-{{{show(dp0, vars, subs)} {show(dp1, vars, subs)}}}"
//         case Sup(sp0, sp1):
//             return f"+{{{show(sp0, vars, subs)} {show(sp1, vars, subs)}}}"
//
//

pub fn reduce(book: *Book, vars: *Vars, subs: *Subs, allocator: std.mem.Allocator) !void {
    var new = struct {
        allocator: std.mem.Allocator,
        book: *Book,

        pub const Self = @This();

        pub fn init(alloc: std.mem.Allocator, book_internal: *Book) Self {
            return .{
                .allocator = alloc,
                .book = book_internal,
            };
        }

        pub fn Redex(self: *Self, content: anytype) !void {
            try self.book.put(self.allocator, .{ .neg = content.@"0", .pos = content.@"1" }, {});
        }
        pub fn App(self: *const Self, arg: *Pos, ret: *Neg) !*Neg {
            const app = try self.allocator.create(Neg);
            app.* = .{ .App = .{
                .arg = arg,
                .ret = ret,
            } };
            return app;
        }
        pub fn Dup(self: *const Self, dp0: *Neg, dp1: *Neg) !*Neg {
            const app = try self.allocator.create(Neg);
            app.* = .{ .Dup = .{
                .dp0 = dp0,
                .dp1 = dp1,
            } };
            return app;
        }
        pub fn Era(self: *const Self) !*Neg {
            const app = try self.allocator.create(Neg);
            app.* = .{ .Era = .{} };
            return app;
        }

        pub fn Lam(self: *const Self, bnd: *Neg, bod: *Pos) !*Pos {
            const app = try self.allocator.create(Pos);
            app.* = .{ .Lam = .{
                .bnd = bnd,
                .bod = bod,
            } };
            return app;
        }
        pub fn Sup(self: *const Self, sp0: *Pos, sp1: *Pos) !*Pos {
            const app = try self.allocator.create(Pos);
            app.* = .{ .Sup = .{
                .sp0 = sp0,
                .sp1 = sp1,
            } };
            return app;
        }
        pub fn Nil(self: *const Self) !*Pos {
            const app = try self.allocator.create(Pos);
            app.* = .{ .Nil = .{} };
            return app;
        }
    }.init(allocator, book);
    while (book.pop()) |redex_kv| {
        const redex = redex_kv.key;
        if (redex.pos.* == .Var) {
            if (vars.fetchRemove(redex.pos.Var.nam)) |target| {
                try book.put(allocator, .{ .neg = redex.neg, .pos = target.value }, {});
            } else {
                try subs.put(redex.pos.Var.nam, redex.neg);
            }
            continue;
        }
        switch (redex.neg.*) {
            .Sub => |neg_sub| {
                if (subs.fetchRemove(neg_sub.nam)) |target| {
                    try book.put(allocator, .{ .neg = target.value, .pos = redex.pos }, {});
                } else {
                    try vars.put(neg_sub.nam, redex.pos);
                }
            },
            .Era => {
                switch (redex.pos.*) {
                    .Nil => {
                        allocator.destroy(redex.neg);
                        allocator.destroy(redex.pos);
                    },
                    .Lam => |pos_lam| {
                        const new_nil = try allocator.create(Pos);
                        new_nil.* = .{ .Nil = .{} };
                        try book.put(allocator, .{ .neg = pos_lam.bnd, .pos = new_nil }, {});
                        try book.put(allocator, .{ .neg = redex.neg, .pos = pos_lam.bod }, {});
                    },
                    .Sup => |pos_sup| {
                        try new.Redex(.{ .neg = try new.Era(), .pos = pos_sup.sp0 });
                        try book.put(allocator, .{ .neg = redex.neg, .pos = pos_sup.sp1 }, {});
                    },
                    else => {},
                }
            },
            .App => |neg_app| {
                switch (redex.pos.*) {
                    .Nil => {
                        try new.Redex(.{ try new.Era(), neg_app.arg });
                        try new.Redex(.{ neg_app.ret, redex.pos });
                        allocator.destroy(redex.neg); // TODO: You do not need to delete it. You can reuse it to store Era :3
                    },
                    .Lam => |pos_lam| {
                        try new.Redex(.{ pos_lam.bnd, neg_app.arg });
                        try new.Redex(.{ neg_app.ret, pos_lam.bod });
                        allocator.destroy(redex.neg);
                        allocator.destroy(redex.pos);
                    },
                    .Sup => |pos_sup| {
                        const wire1 = try wire(allocator);
                        const wire2 = try wire(allocator);
                        const wire3 = try wire(allocator);
                        const wire4 = try wire(allocator);
                        try new.Redex(.{ try new.Dup(wire1.@"0", wire2.@"0"), neg_app.arg });
                        try new.Redex(.{ try new.App(wire1.@"1", wire3.@"0"), pos_sup.sp0 });
                        try new.Redex(.{ try new.App(wire2.@"1", wire4.@"0"), pos_sup.sp1 });
                        redex.pos.* = .{ .Sup = .{ .sp0 = wire3.@"1", .sp1 = wire4.@"1" } };
                        try new.Redex(.{ neg_app.ret, redex.pos });
                        allocator.destroy(redex.neg);
                    },
                    else => {},
                }
            },
            .Dup => |neg_dup| {
                switch (redex.pos.*) {
                    .Nil => {
                        try new.Redex(.{ neg_dup.dp0, redex.pos });
                        try new.Redex(.{ neg_dup.dp1, try new.Nil() });
                    },
                    .Lam => |pos_lam| {
                        const wire1 = try wire(allocator);
                        const wire2 = try wire(allocator);
                        const wire3 = try wire(allocator);
                        const wire4 = try wire(allocator);
                        const lam_bnd = pos_lam.bnd;
                        const lam_bod = pos_lam.bod;
                        redex.pos.* = .{ .Lam = .{ .bnd = wire1.@"0", .bod = wire2.@"1" } };
                        try new.Redex(.{ neg_dup.dp0, redex.pos });
                        try new.Redex(.{ neg_dup.dp1, try new.Lam(wire3.@"0", wire4.@"1") });
                        try new.Redex(.{ lam_bnd, try new.Sup(wire1.@"1", wire3.@"1") });
                        redex.neg.* = .{ .Dup = .{ .dp0 = wire2.@"0", .dp1 = wire4.@"0" } };
                        try new.Redex(.{ redex.neg, lam_bod });
                    },
                    .Sup => |pos_sup| {
                        try new.Redex(.{ neg_dup.dp0, pos_sup.sp0 });
                        try new.Redex(.{ neg_dup.dp1, pos_sup.sp1 });
                        allocator.destroy(redex.neg);
                        allocator.destroy(redex.pos);
                    },
                    else => {},
                }
            },
        }
    }
}

test "Basic reductions" {
    const allocator = std.testing.allocator;
    const New = struct {
        allocator: std.mem.Allocator,
        book: *Book,

        pub const Self = @This();

        pub fn init(book: *Book) Self {
            return .{
                .allocator = allocator,
                .book = book,
            };
        }

        pub fn Redex(self: *Self, content: anytype) !void {
            try self.book.put(self.allocator, .{ .neg = content.@"0", .pos = content.@"1" }, {});
        }
        pub fn App(self: *const Self, arg: *Pos, ret: *Neg) !*Neg {
            const app = try self.allocator.create(Neg);
            app.* = .{ .App = .{
                .arg = arg,
                .ret = ret,
            } };
            return app;
        }
        pub fn Dup(self: *const Self, dp0: *Neg, dp1: *Neg) !*Neg {
            const app = try self.allocator.create(Neg);
            app.* = .{ .Dup = .{
                .dp0 = dp0,
                .dp1 = dp1,
            } };
            return app;
        }
        pub fn Era(self: *const Self) !*Neg {
            const app = try self.allocator.create(Neg);
            app.* = .{ .Era = .{} };
            return app;
        }
        pub fn Sub(self: *const Self, nam: u32) !*Neg {
            const app = try self.allocator.create(Neg);
            app.* = .{ .Sub = .{ .nam = nam } };
            return app;
        }

        pub fn Lam(self: *const Self, bnd: *Neg, bod: *Pos) !*Pos {
            const app = try self.allocator.create(Pos);
            app.* = .{ .Lam = .{
                .bnd = bnd,
                .bod = bod,
            } };
            return app;
        }
        pub fn Sup(self: *const Self, sp0: *Pos, sp1: *Pos) !*Pos {
            const app = try self.allocator.create(Pos);
            app.* = .{ .Sup = .{
                .sp0 = sp0,
                .sp1 = sp1,
            } };
            return app;
        }
        pub fn Nil(self: *const Self) !*Pos {
            const app = try self.allocator.create(Pos);
            app.* = .{ .Nil = .{} };
            return app;
        }
        pub fn Var(self: *const Self, nam: u32) !*Pos {
            const app = try self.allocator.create(Pos);
            app.* = .{ .Var = .{ .nam = nam } };
            return app;
        }
    };
    {
        var subs: Subs = .init(allocator);
        var vars: Vars = .init(allocator);
        var book: Book = try .init(allocator, &[_]Rdx{}, &[_]void{});
        var new: New = .init(&book);
        const rhs_lambda = try new.Lam(try new.Dup(try new.Sub(500), try new.App(try new.Var(500), try new.Sub(501))), try new.Var(501));
        const lhs_application = try new.App(try new.Lam(try new.Sub(502), try new.Var(502)), try new.Sub(503));
        const root: Term = .{ .Pos = try new.Var(503) };
        try new.Redex(.{ lhs_application, rhs_lambda });
        try reduce(&book, &vars, &subs, allocator);
        const formatted = try show(root, &vars, &subs, allocator);
        std.debug.print("{s}\n", .{formatted});

        rhs_lambda.deinit(allocator);
        lhs_application.deinit(allocator);
        allocator.free(formatted);
        vars.deinit();
        subs.deinit();
        book.deinit(allocator);
    }
}
