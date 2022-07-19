const std = @import("std");
const stb = @import("stbImageWrite.zig");
const zigargs = @import("zigargs");
const Rgba32 = @import("drawer.zig").Rgba32;
const Drawer = @import("drawer.zig").Drawer;
const Model = @import("model.zig").Model;
const Circle = @import("model.zig").Circle;
const Line = @import("model.zig").Line;

const MAX_WRITE_THREADS = 20;
const MIN_WIDTH = 128;
const MIN_HEIGHT = 128;
const LINES = 0;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var alloc = gpa.allocator();

    var out = std.io.getStdOut();
    var w = out.writer();

    const args = try Args.parse(alloc);
    defer args.deinit();

    var circles = try initCircles(args.options, alloc);
    defer {
        for (circles) |*c| {
            c.deinit(alloc);
        }
        alloc.free(circles);
    }

    var lines: [LINES]Line = switch (LINES) {
        4 => .{
            Line.new(.horizontal, 5, args.options.width - 5, 5),
            Line.new(.horizontal, 5, args.options.width - 5, args.options.height - 5),
            Line.new(.vertical, 5, args.options.height - 5, 5),
            Line.new(.vertical, 5, args.options.height - 5, args.options.width - 5),
        },
        0 => .{},
        else => @compileError("unsupported number of lines"),
    };

    var model = Model.new(circles, &lines, args.options.width, args.options.height);

    try std.fs.cwd().deleteTree("out");
    try std.fs.cwd().makeDir("out");

    try runSimulation(args.options, alloc, &model, w);
}

const Args = struct {
    const Self = @This();

    width: isize = 1024,
    height: isize = 1024,
    frames: usize = 1024,
    frame_block: usize = 1024,
    write_threads: usize = 10,
    circles: usize = 100,

    pub const shorthands = .{
        .w = "width",
        .h = "height",
        .f = "frames",
        .b = "frame_block",
        .t = "write_threads",
        .c = "circles",
    };

    fn parse(alloc: std.mem.Allocator) !zigargs.ParseArgsResult(Self, null) {
        const args = try zigargs.parseForCurrentProcess(Args, alloc, .print);
        errdefer args.deinit();

        if (args.options.write_threads > MAX_WRITE_THREADS) {
            return error.OverMaxWriteThreads;
        }

        if (args.options.width < 128) {
            return error.BelowMinWidth;
        }

        if (args.options.height < 128) {
            return error.BelowMinHeight;
        }

        return args;
    }
};

fn initCircles(args: Args, alloc: std.mem.Allocator) ![]Circle {
    var rng = std.rand.DefaultPrng.init(@truncate(u64, @bitCast(u128, std.time.nanoTimestamp())));

    var circles = try alloc.alloc(Circle, args.circles);
    var computed: usize = 0;
    errdefer {
        for (circles[0..computed]) |*c| {
            c.deinit(alloc);
        }
        alloc.free(circles);
    }

    for (circles) |*c, i| {
        c.* = try Circle.new(args.width, args.height, &rng, alloc);
        while (hasCollision(c.*, circles[0..i])) {
            c.deinit(alloc);
            c.* = try Circle.new(args.width, args.height, &rng, alloc);
        }
        computed = i;
    }

    return circles;
}

fn hasCollision(circle: Circle, circles: []Circle) bool {
    for (circles) |c| {
        if (c.hasCollisionCircle(circle)) {
            return true;
        }
    }
    return false;
}

fn runSimulation(args: Args, alloc: std.mem.Allocator, model: *Model, w: anytype) !void {
    try w.print("rendering {} frames...\n", .{args.frames});

    var frames = try std.ArrayList(Drawer).initCapacity(alloc, args.frame_block);
    defer frames.deinit();

    var frame: u24 = 0;
    while (frame < args.frames) {
        var frameStart = frame;

        defer {
            for (frames.items) |*d| {
                d.deinit();
            }
            frames.clearRetainingCapacity();
        }

        while (frame < frameStart + args.frame_block and frame < args.frames) : (frame += 1) {
            try w.print("\rsimulation: {d: >3.1}%", .{@intToFloat(f64, frame + 1) / @intToFloat(f64, args.frames) * 100.0});

            var drawer = try Drawer.new(args.width, args.height, alloc);
            errdefer drawer.deinit();
            model.draw(&drawer);
            model.iterate();

            try frames.append(drawer);
        }

        try w.print("\nsaving frames {} to {}...", .{ frameStart + 1, frame });
        var frameCount = std.atomic.Atomic(usize).init(0);
        var writeThreadsBuf: [MAX_WRITE_THREADS]std.Thread = undefined;
        var writeThreads = writeThreadsBuf[0..args.write_threads];
        var threadError = false;
        var spawned: usize = 0;
        errdefer {
            for (writeThreads[0..spawned]) |t| {
                t.join();
            }
        }
        for (writeThreads) |*t, i| {
            t.* = try std.Thread.spawn(.{}, fileSaver, .{ args, &frameCount, &threadError, frames.items, frameStart });
            spawned = i;
        }
        for (writeThreads) |*t| {
            t.join();
        }
        if (!threadError) {
            try w.print("\nsuccessfully saved frames!\n", .{});
        } else {
            try w.print("\nthere was an error saving some frames\n", .{});
        }
    }
}

fn fileSaver(args: Args, spawned: *std.atomic.Atomic(usize), threadError: *bool, frames: []Drawer, frameStart: usize) void {
    while (true) {
        var file = spawned.fetchAdd(1, .SeqCst);
        if (file >= frames.len) {
            return;
        }
        fileSaverInner(args, file, frames, frameStart) catch |err| {
            std.debug.print("\nerror: {}\n", .{err});
            threadError.* = true;
            return;
        };
    }
}

fn fileSaverInner(args: Args, frame: usize, frames: []Drawer, frameStart: usize) !void {
    var drawer = frames[frame];
    var nameBuf: [128]u8 = undefined;
    var fileName = try std.fmt.bufPrintZ(&nameBuf, "out/{:0>4}.png", .{frame + frameStart});
    var pngWriteResult = stb.stbi_write_png(
        fileName.ptr,
        @intCast(c_int, args.width),
        @intCast(c_int, args.height),
        4,
        drawer.ptr(),
        0,
    );
    if (pngWriteResult == 0) {
        return error.FailedtoConvertQoi;
    }
}
