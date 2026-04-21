const std = @import("std");
const ast = @import("ast.zig");
const yazap = @import("yazap");

const Io = std.Io;
const version: struct { major: u32, minor: u32, patch: u32, dev: bool } = .{
    .major = 0, //
    .minor = 0,
    .patch = 0,
    .dev = true,
};
var verbosity: u8 = 0;

const ArgContext = struct {
    const Subcommands = union(enum) {
        run: struct {
            file_path: []const u8,
            verbosity: u8 = 0,
        },
        version: struct {},
    };
    subcommand: Subcommands,

    pub fn create_cli(app: *yazap.App) !void {
        var hascoil_app = app.rootCommand();
        hascoil_app.setProperty(.help_on_empty_args);
        const version_cmd = app.createCommand("version", "Print HasCOIL runtime version");
        try hascoil_app.addSubcommand(version_cmd);

        var run_cmd = app.createCommand("run", "Run a .hc file");
        try run_cmd.addArg(yazap.Arg.positional("file", null, null));
        run_cmd.setProperty(.help_on_empty_args);
        run_cmd.setProperty(.positional_arg_required);
        try run_cmd.addArg(yazap.Arg.booleanOption("error", null, "Set log level to error. Superceedes info, debug, warn"));
        try run_cmd.addArg(yazap.Arg.booleanOption("warn", null, "Set log level to error. Superceedes info, debug"));
        try run_cmd.addArg(yazap.Arg.booleanOption("debug", null, "Set log level to error. Superceedes info"));
        try run_cmd.addArg(yazap.Arg.booleanOption("info", null, "Set log level to error. Superceedes none"));
        try hascoil_app.addSubcommand(run_cmd);
    }

    pub fn parse_match(matches: yazap.ArgMatches) !ArgContext {
        if (matches.subcommandMatches("version")) |_| {
            return .{ .subcommand = .{ .version = .{} } };
        } else if (matches.subcommandMatches("run")) |run_matches| {
            return .{
                .subcommand = .{
                    .run = .{ //
                        .file_path = if (run_matches.getSingleValue("file")) |file| file else "",
                        .verbosity = if (run_matches.containsArg("error")) 0 else if (run_matches.containsArg("warn")) 1 else if (run_matches.containsArg("debug")) 2 else if (run_matches.containsArg("info")) 3 else 4,
                    },
                },
            };
        }
        return error.NoSubcommand;
    }
};

pub var stdout: *std.Io.Writer = undefined;
pub var io: std.Io = undefined;
pub const std_options: std.Options = .{
    .logFn = struct {
        fn do(comptime level: std.log.Level, comptime scope: @EnumLiteral(), comptime format: []const u8, args: anytype) void {
            const int_level = switch (level) {
                .err => 0,
                .warn => 1,
                .debug => 2,
                .info => 3,
            };
            if (int_level < verbosity) return;
            // const io = std.Options.debug_io;
            const prev = io.swapCancelProtection(.blocked);
            defer _ = io.swapCancelProtection(prev);
            var buffer: [64]u8 = undefined;
            const stderr = std.debug.lockStderr(&buffer).terminal();
            defer std.debug.unlockStderr();

            stderr.setColor(.black) catch {};
            const bg_color = switch (level) {
                .err => "\u{001b}[41m",
                .warn => "\u{001b}[43m",
                .info => "\u{001b}[42m",
                .debug => "\u{001b}[45m",
            };
            const level_name = switch (level) {
                .err => " err  :",
                .warn => " warn :",
                .info => " info :",
                .debug => " debug:",
            };
            stderr.writer.writeAll(bg_color) catch {};
            stderr.setColor(.bold) catch {};
            stderr.writer.writeAll(level_name) catch {};
            stderr.setColor(.reset) catch {};
            stderr.setColor(.dim) catch {};
            stderr.setColor(.bold) catch {};
            if (scope != .default) stderr.writer.print(" scope: ({t}):", .{scope}) catch {};
            stderr.setColor(.reset) catch {};
            stderr.writer.print(" " ++ format ++ "\n", args) catch {};
        }
    }.do,
};

pub fn main(init: std.process.Init) !void {
    io = init.io;
    const allocator = init.gpa;

    var app = yazap.App.init(allocator, "HasCOIL", "description");
    defer app.deinit();

    try ArgContext.create_cli(&app);

    var stdout_buffer: [256]u8 = undefined;
    const stdout_file = std.Io.File.stdout();
    var stdout_writer_impl = stdout_file.writer(io, &stdout_buffer);
    stdout = &stdout_writer_impl.interface;

    const matches = app.parseProcess(io, init.minimal.args) catch {
        return;
    };
    const parsed_args = try ArgContext.parse_match(matches);
    if (parsed_args.subcommand == .version) {
        if (version.dev) {
            try stdout.print("{d}.{d}.{d}-dev", .{ version.major, version.minor, version.patch });
        } else {
            try stdout.print("{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
        }
        try stdout.flush();
        return;
    }
    var file_name: []const u8 = undefined;
    if (parsed_args.subcommand == .run) {
        file_name = parsed_args.subcommand.run.file_path;
        verbosity = parsed_args.subcommand.run.verbosity;
        std.log.info("Running contents of {s}", .{parsed_args.subcommand.run.file_path});
    }

    var reader_buffer: [256]u8 = undefined;
    const source_file = std.Io.Dir.openFile(std.Io.Dir.cwd(), io, file_name, .{}) catch {
        try stdout.print("Could not find file: {s}\n", .{file_name});
        try stdout.flush();
        return;
    };
    defer source_file.close(io);
    var reader_impl = source_file.reader(io, &reader_buffer);
    const source_reader = &reader_impl.interface;
    const source = try source_reader.readAlloc(allocator, try source_file.length(io));
    defer allocator.free(source);

    var parser = try ast.Parser.init(source, allocator);
    defer parser.deinit();
    const exprs = try parser.parse();

    for (exprs.items) |expr| {
        try expr.format(source, stdout, 80);
    }

    try stdout.flush();
}
