const std = @import("std");
const zigimg = @import("zigimg");
const Image = zigimg.Image;
const Rgba32 = zigimg.color.Rgba32;

const Drawer = @import("drawer.zig").Drawer;

pub const Model = struct {
    const Self = @This();

    width: usize,
    height: usize,
    circles: []Circle,

    pub fn new(circles: []Circle, width: usize, height: usize) Self {
        return .{
            .width = width,
            .height = height,
            .circles = circles,
        };
    }

    pub fn iterate(self: *Self) void {
        for (self.circles) |*c| {
            c.iterate(self.width, self.height);
        }
    }

    pub fn draw(self: Self, drawer: *Drawer) void {
        for (self.circles) |c| {
            c.draw(drawer);
        }
    }
};

pub const Circle = struct {
    const Self = @This();

    colour: Rgba32,
    movement: Point,
    centre: Point,
    radius: f64,

    pub fn new(w: usize, h: usize, rng: *std.rand.DefaultPrng) Self {
        var angle = rng.random().float(f64) * 2 * std.math.pi;
        return .{ .colour = Rgba32.initRgba(
            rng.random().int(u8),
            rng.random().int(u8),
            rng.random().int(u8),
            255,
        ), .movement = .{
            .x = @sin(angle),
            .y = @cos(angle),
        }, .centre = .{
            .x = rng.random().float(f64) * @intToFloat(f64, w),
            .y = rng.random().float(f64) * @intToFloat(f64, h),
        }, .radius = 5 };
    }

    fn iterate(self: *Self, width: usize, height: usize) void {
        self.centre = self.centre.add(self.movement);
        self.centre.x = @mod(self.centre.x, @intToFloat(f64, width));
        self.centre.y = @mod(self.centre.y, @intToFloat(f64, height));
    }

    fn draw(self: Self, drawer: *Drawer) void {
        var x: isize = -1;

        while (x < 2) : (x += 1) {
            var y: isize = -1;
            while (y < 2) : (y += 1) {
                drawer.place(
                    x + @floatToInt(isize, self.centre.x),
                    y + @floatToInt(isize, self.centre.y),
                    self.colour,
                );
            }
        }
    }
};

const Point = struct {
    x: f64,
    y: f64,

    fn add(a: Point, b: Point) Point {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
        };
    }
};
