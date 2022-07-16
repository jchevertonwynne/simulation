const std = @import("std");
const Rgba32 = @import("zigimg").color.Rgba32;
const qoi = @import("qoi.zig");
const stb = @import("stbImageWrite.zig");
const Drawer = @import("drawer.zig").Drawer;
const Model = @import("model.zig").Model;
const Circle = @import("model.zig").Circle;

const WIDTH = 1024;
const HEIGHT = 1024;
const FRAMES = 1;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var alloc = gpa.allocator();
    var imgBuf = try alloc.alloc(Rgba32, WIDTH * HEIGHT);
    defer alloc.free(imgBuf);

    var drawer = Drawer.new(imgBuf, WIDTH, HEIGHT);

    var rng = std.rand.DefaultPrng.init(@truncate(u64, @bitCast(u128, std.time.nanoTimestamp())));

    var circles: [1024]Circle = undefined;
    for (circles) |*c| {
        c.* = Circle.new(WIDTH, HEIGHT, &rng);
    }

    var model = Model.new(&circles, WIDTH, HEIGHT);

    try std.fs.cwd().deleteTree("outpng");
    try std.fs.cwd().makeDir("outpng");

    var out = std.io.getStdOut();
    var w = out.writer();

    var frame: u24 = 0;
    while (frame < FRAMES) : (frame += 1) {
        try w.print("\r{0d: >3.1}%", .{@intToFloat(f64, frame + 1) / @intToFloat(f64, FRAMES) * 100.0});

        for (imgBuf) |*p| {
            p.* = Rgba32.initRgba(0, 0, 0, 255);
        }
        model.iterate();
        model.draw(&drawer);

        var qoi_desc: qoi.qoi_desc = .{
            .width = WIDTH,
            .height = HEIGHT,
            .channels = 4,
            .colorspace = 0,
        };
        var outLen: c_int = undefined;
        var qoiFile = qoi.qoi_encode(imgBuf.ptr, &qoi_desc, &outLen) orelse return error.FailedToReadQoiFile;
        defer qoi.qoi_free(qoiFile);

        try std.fs.cwd().writeFile("out.qoi", @ptrCast([*]u8, @alignCast(@alignOf(u8), qoiFile))[0..@intCast(usize, outLen)]);

        var nameBuf: [128]u8 = undefined;
        var fileName = try std.fmt.bufPrintZ(&nameBuf, "outpng/{:0>4}.png", .{frame});
        var width = @bitCast(c_int, qoi_desc.width);
        var height = @bitCast(c_int, qoi_desc.height);
        var channels = qoi_desc.channels;
        var pngWriteResult = stb.stbi_write_png(fileName.ptr, width, height, channels, qoiFile, 0);
        if (pngWriteResult == 0) {
            return error.FailedtoConvertQoi;
        }
    }
    try w.print("\n", .{});
}
