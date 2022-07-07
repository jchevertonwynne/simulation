const std = @import("std");
const zigimg = @import("zigimg");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var alloc = gpa.allocator();
    var img = try zigimg.image.Image.create(alloc, 10, 10, .rgba32, .qoi);
    defer img.deinit();

    if (img.pixels) |*pixels| {
        for (pixels.rgba32) |*p| {
            p.* = zigimg.color.Rgba32.initRgba(0, 0, 0, 0);
        }
    }

    var buf = try alloc.alloc(u8, 22 + (10 * 10 * 4));
    defer alloc.free(buf);

    for (buf) |*b|
        b.* = 0; 
    var result = try img.writeToMemory(buf, .qoi, .none);

    var file = try std.fs.cwd().createFile("out.qoi", .{});
    defer file.close();

    try file.writeAll(result);

}

test "should have valid qoi image" {
    var img = try zigimg.Image.fromFilePath(std.testing.allocator, "out.qoi");
    defer img.deinit();

    std.testing.expect(img.pixelFormat() == .rgba32);
}