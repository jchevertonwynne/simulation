const std = @import("std");
const zigimg = @import("zigimg");
const Image = zigimg.Image;
const Rgba32 = zigimg.color.Rgba32;

pub const Drawer = struct {
    const Self = @This();

    img: []Rgba32,
    width: usize,
    height: usize,

    pub fn new(img: []Rgba32, width: usize, height: usize) Self {
        return .{
            .img = img,
            .width = width,
            .height = height,
        };
    }

    pub fn place(self: *Self, x: isize, y: isize, pixel: zigimg.color.Rgba32) void {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return;
        }

        self.img[@bitCast(usize, x) + @bitCast(usize, y) * self.width] = pixel;
    }
};
