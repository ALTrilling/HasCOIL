const std = @import("std");
const ast = @import("ast.zig");
const yazap = @import("yazap");

const Io = std.Io;

pub var stdout: *std.Io.Writer = undefined;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    var app = yazap.App.init(allocator, "HasCOIL", "description");
    defer app.deinit();

    var hascoil_app = app.rootCommand();
    hascoil_app.setProperty(.help_on_empty_args);

    try hascoil_app.addArg(yazap.Arg.positional("file", null, null));
    hascoil_app.setProperty(.positional_arg_required);

    var stdout_buffer: [256]u8 = undefined;
    const stdout_file = std.Io.File.stdout();
    var stdout_writer_impl = stdout_file.writer(io, &stdout_buffer);
    stdout = &stdout_writer_impl.interface;

    const matches = try app.parseProcess(io, init.minimal.args);
    var file_name: []const u8 = undefined;
    if (matches.getSingleValue("file")) |file| {
        file_name = file;
        std.log.info("List contents of {s}", .{file});
    }

    var reader_buffer: [256]u8 = undefined;
    const source_file = std.Io.Dir.openFile(std.Io.Dir.cwd(), io, file_name, .{}) catch {
        std.debug.print("Could not find file: {s}\n", .{file_name});
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
        try expr.format(source, stdout, 30);
    }

    try stdout.flush();
}
