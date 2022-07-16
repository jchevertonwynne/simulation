const std = @import("std");
const stb = @import("stbImageWrite.zig");
const Rgba32 = @import("drawer.zig").Rgba32;
const Drawer = @import("drawer.zig").Drawer;
const Model = @import("model.zig").Model;
const Circle = @import("model.zig").Circle;
const Line = @import("model.zig").Line;

const WIDTH = 512;
const HEIGHT = 512;
const FRAMES = 1024;
const CIRCLES = 4;
const LINES = 4;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var alloc = gpa.allocator();

    var drawer = try Drawer.new(WIDTH, HEIGHT, alloc);
    defer drawer.deinit();

    var rng = std.rand.DefaultPrng.init(@truncate(u64, @bitCast(u128, std.time.nanoTimestamp())));

    var circles: [CIRCLES]Circle = undefined;
    var computed: usize = 0;
    errdefer {
        for (circles[0..computed]) |*c| {
            c.deinit(alloc);
        }
    }

    for (circles) |*c, i| {
        c.* = try Circle.new(WIDTH, HEIGHT, &rng, alloc);
        while (hasCollision(c.*, circles[0..i])) {
            c.deinit(alloc);
            c.* = try Circle.new(WIDTH, HEIGHT, &rng, alloc);
        }
        computed = i;
    }

    var lines: [LINES]Line = .{
        Line.new(.horizontal, 5, WIDTH - 5, 5),
        Line.new(.horizontal, 5, WIDTH - 5, HEIGHT - 5),
        Line.new(.vertical, 5, HEIGHT - 5, 5),
        Line.new(.vertical, 5, HEIGHT - 5, WIDTH - 5),
    };

    var model = Model.new(&circles, &lines, WIDTH, HEIGHT);

    try std.fs.cwd().deleteTree("out");
    try std.fs.cwd().makeDir("out");

    var out = std.io.getStdOut();
    var w = out.writer();

    try w.print("rendering {} frames...\n", .{FRAMES});

    var frame: u24 = 0;
    while (frame < FRAMES) : (frame += 1) {
        try w.print("\r{0d: >3.1}%", .{@intToFloat(f64, frame + 1) / @intToFloat(f64, FRAMES) * 100.0});

        drawer.reset();
        model.draw(&drawer);
        model.iterate();

        var nameBuf: [128]u8 = undefined;
        var fileName = try std.fmt.bufPrintZ(&nameBuf, "out/{:0>4}.png", .{frame});
        var pngWriteResult = stb.stbi_write_png(
            fileName.ptr,
            WIDTH,
            HEIGHT,
            4,
            drawer.ptr(),
            0,
        );
        if (pngWriteResult == 0) {
            return error.FailedtoConvertQoi;
        }
    }
    try w.print("\n", .{});
}

fn hasCollision(circle: Circle, circles: []Circle) bool {
    for (circles) |c| {
        if (c.hasCollisionCircle(circle)) {
            return true;
        }
    }
    return false;
}
