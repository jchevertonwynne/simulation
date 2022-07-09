const std = @import("std");
const zigimg = @import("zigimg");
const Image = zigimg.Image;
const Rgba32 = zigimg.color.Rgba32;
const stbImageWrite = @import("stbImageWrite.zig");
const qoi = @import("qoi.zig");

const WIDTH = 1024;
const HEIGHT = 1024;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var alloc = gpa.allocator();
    var img = try Image.create(alloc, WIDTH, HEIGHT, .rgba32, .qoi);
    defer img.deinit();

    var buf = try alloc.alloc(u8, 22 + (WIDTH * HEIGHT * 4));
    defer alloc.free(buf);

    var i: usize = 0;
    while (i < 2400) : (i += 1) {
        var col: u24 = @truncate(u24, i);

        if (img.pixels) |*pixels| {
            for (pixels.rgba32) |*p| {
                var r = @truncate(u8, col >> 16);
                var g = @truncate(u8, col >> 8);
                var b = @truncate(u8, col);
                p.* = Rgba32.initRgba(r, g, b, 255);
                col +%= 1;
            }
        }
        var result = try img.writeToMemory(buf, .qoi, .none);

        var nameBuf: [20]u8 = undefined;
        var fileName = try std.fmt.bufPrint(&nameBuf, "out/{:0>4}.qoi", .{i});
        {
            var file = try std.fs.cwd().createFile(fileName, .{});
            defer file.close();

            try file.writeAll(result);
        }

        var qoi_desc: qoi.qoi_desc = undefined;
        var readQoiFile = qoi.qoi_read(fileName.ptr, &qoi_desc, 4) orelse return error.FailedToReadQoiFile;
        // defer std.heap.c_allocator.free(readQoiFile);

        fileName = try std.fmt.bufPrint(&nameBuf, "out2/{:0>4}.qoi", .{i});
        var width = @bitCast(c_int, qoi_desc.width);
        var height = @bitCast(c_int, qoi_desc.height);
        var channels = qoi_desc.channels;
        var result2 = stbImageWrite.stbi_write_png(fileName.ptr, width, height, channels, readQoiFile, 0);
        if (result2 == 0) {
            return error.FailedtoConvertQoi;
        }
    }
}
