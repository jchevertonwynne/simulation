const std = @import("std");
const Rgba32 = @import("zigimg").color.Rgba32;
const stb = @import("stbImageWrite.zig");
const Drawer = @import("drawer.zig").Drawer;
const Model = @import("model.zig").Model;
const Circle = @import("model.zig").Circle;

const WIDTH = 1024;
const HEIGHT = 1024;
const FRAMES = 1024;
const CIRCLES = 100;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var alloc = gpa.allocator();
    var imgBuf = try alloc.alloc(Rgba32, WIDTH * HEIGHT);
    defer alloc.free(imgBuf);

    var drawer = Drawer.new(imgBuf, WIDTH, HEIGHT);

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
        computed = i;
    }

    var model = Model.new(&circles, WIDTH, HEIGHT);

    try std.fs.cwd().deleteTree("outpng");
    try std.fs.cwd().makeDir("outpng");

    var out = std.io.getStdOut();
    var w = out.writer();

    try w.print("rendering {} frames...\n", .{FRAMES});

    var frame: u24 = 0;
    while (frame < FRAMES) : (frame += 1) {
        try w.print("\r{0d: >3.1}%", .{@intToFloat(f64, frame + 1) / @intToFloat(f64, FRAMES) * 100.0});

        for (imgBuf) |*p| {
            p.* = Rgba32.initRgba(0, 0, 0, 255);
        }
        model.iterate();
        model.draw(&drawer);

        var nameBuf: [128]u8 = undefined;
        var fileName = try std.fmt.bufPrintZ(&nameBuf, "outpng/{:0>4}.png", .{frame});
        var pngWriteResult = stb.stbi_write_png(
            fileName.ptr,
            WIDTH,
            HEIGHT,
            4,
            imgBuf.ptr,
            0,
        );
        if (pngWriteResult == 0) {
            return error.FailedtoConvertQoi;
        }
    }
    try w.print("\n", .{});
}
