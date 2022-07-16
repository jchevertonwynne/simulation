const std = @import("std");

pub const Rgba32 = struct {
    const Self = @This();

    inner: [4]u8,

    pub fn new(r: u8, g: u8, b: u8, a: u8) Self {
        return .{ .inner = .{ r, g, b, a } };
    }

    pub fn red() Self {
        return Self.new(255, 0, 0, 255);
    }

    pub fn green() Self {
        return Self.new(0, 255, 0, 255);
    }

    pub fn blue() Self {
        return Self.new(0, 0, 255, 255);
    }
};

pub const Drawer = struct {
    const Self = @This();

    img: []u8,
    width: usize,
    height: usize,
    alloc: std.mem.Allocator,

    pub fn new(width: usize, height: usize, alloc: std.mem.Allocator) !Self {
        var img = try alloc.alloc(u8, width * height * 4);
        return Self{
            .img = img,
            .width = width,
            .height = height,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.img);
    }

    pub fn reset(self: *Self) void {
        var w: isize = 0;
        while (w < self.width) : (w += 1) {
            var h: isize = 0;
            while (h < self.height) : (h += 1) {
                self.place(w, h, Rgba32.new(0, 0, 0, 255));
            }
        }
    }

    pub fn ptr(self: *Self) [*]u8 {
        return self.img.ptr;
    }

    pub fn place(self: *Self, x: isize, y: isize, pixel: Rgba32) void {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return;
        }

        std.mem.copy(u8, self.img[(@bitCast(usize, x) + @bitCast(usize, y) * self.width) * 4 ..], &pixel.inner);
    }
};
