const std = @import("std");
const zigimg = @import("zigimg");
const Image = zigimg.Image;
const Rgba32 = zigimg.color.Rgba32;
const qoi = @import("qoi.zig");
const stb = @import("stbImageWrite.zig");

const WIDTH = 512;
const HEIGHT = 512;
const FRAMES = 1024;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var alloc = gpa.allocator();
    var img = try Image.create(alloc, WIDTH, HEIGHT, .rgba32, .qoi);
    defer img.deinit();

    try std.fs.cwd().deleteTree("outqoi");
    try std.fs.cwd().deleteTree("outpng");
    try std.fs.cwd().makeDir("outqoi");
    try std.fs.cwd().makeDir("outpng");

    var buf = try alloc.alloc(u8, 22 + (WIDTH * HEIGHT * 4));
    defer alloc.free(buf);

    var out = std.io.getStdOut();
    var w = out.writer();

    var i: u24 = 0;
    while (i < FRAMES) : (i += 1) {
        try w.print("creating frame {}/{}\n", .{i, FRAMES});
        var col = i;

        if (img.pixels) |*pixels| {
            for (pixels.rgba32) |*p| {
                var r = @truncate(u8, col >> 16);
                var g = @truncate(u8, col >> 8);
                var b = @truncate(u8, col);
                p.* = Rgba32.initRgba(r, g, b, 255);
                col +%= 1;
            }
        }
        var qoiRender = try img.writeToMemory(buf, .qoi, .none);

        var nameBuf: [40]u8 = undefined;
        var fileName = try std.fmt.bufPrint(&nameBuf, "outqoi/{:0>4}.qoi", .{i});
        {
            var file = try std.fs.cwd().createFile(fileName, .{});
            defer file.close();

            try file.writeAll(qoiRender);
        }
        nameBuf[fileName.len] = 0;

        var qoi_desc: qoi.qoi_desc = undefined;
        var readQoiFile = qoi.qoi_read(fileName.ptr, &qoi_desc, 4) orelse return error.FailedToReadQoiFile;
        defer qoi.qoi_free(readQoiFile);

        fileName = try std.fmt.bufPrint(&nameBuf, "outpng/{:0>4}.png", .{i});
        nameBuf[fileName.len] = 0;
        var width = @bitCast(c_int, qoi_desc.width);
        var height = @bitCast(c_int, qoi_desc.height);
        var channels = qoi_desc.channels;
        var pngWriteResult = stb.stbi_write_png(fileName.ptr, width, height, channels, readQoiFile, 0);
        if (pngWriteResult == 0) {
            return error.FailedtoConvertQoi;
        }
    }
}
