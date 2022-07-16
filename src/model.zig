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

        for (self.circles) |*c1, ind1| {
            for (self.circles[ind1+1..]) |*c2| {
                Circle.collide(c1, c2);
            }
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
    movement: Point(f64),
    centre: Point(f64),
    radius: isize,
    arc: []Point(isize),

    pub fn new(w: usize, h: usize, rng: *std.rand.DefaultPrng, alloc: std.mem.Allocator) !Self {
        var angle = rng.random().float(f64) * 2 * std.math.pi;
        var radius = @rem(rng.random().int(isize), 5) + 5;
        return Self{
            .colour = Rgba32.initRgba(
                rng.random().int(u8),
                rng.random().int(u8),
                rng.random().int(u8),
                255,
            ),
            .movement = .{
                .x = @sin(angle),
                .y = @cos(angle),
            },
            .centre = .{
                .x = rng.random().float(f64) * @intToFloat(f64, w),
                .y = rng.random().float(f64) * @intToFloat(f64, h),
            },
            .radius = radius,
            .arc = try calculateArc(radius, alloc),
        };
    }

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        alloc.free(self.arc);
    }

    pub fn collide(a: *Self, b: *Self) void {
        var x = std.math.fabs(a.centre.x - b.centre.x);
        var y = std.math.fabs(a.centre.y - b.centre.y);
        if (pow(x, 2) + pow(y, 2) > pow(@intToFloat(f64, a.radius) + @intToFloat(f64, b.radius), 2)) {
            return;
        }

        // TODO - https://ericleong.me/research/circle-circle/#:~:text=Determining%20whether%20or%20not%20two,squared%20between%20the%20two%20circles.

        a.movement = .{ .x = - a.movement.x, .y = - a.movement.y };
        b.movement = .{ .x = - b.movement.x, .y = - b.movement.y };
    }

    fn iterate(self: *Self, width: usize, height: usize) void {
        self.centre = self.centre.add(self.movement);
        self.centre.x = @mod(self.centre.x, @intToFloat(f64, width));
        self.centre.y = @mod(self.centre.y, @intToFloat(f64, height));
    }

    fn draw(self: Self, drawer: *Drawer) void {
        for (self.arc) |a| {
            drawer.place(
                @floatToInt(isize, self.centre.x) + a.x,
                @floatToInt(isize, self.centre.y) + a.y,
                self.colour,
            );
            
            drawer.place(
                @floatToInt(isize, self.centre.x) - a.x,
                @floatToInt(isize, self.centre.y) + a.y,
                self.colour,
            );
            
            drawer.place(
                @floatToInt(isize, self.centre.x) + a.x,
                @floatToInt(isize, self.centre.y) - a.y,
                self.colour,
            );
            
            drawer.place(
                @floatToInt(isize, self.centre.x) - a.x,
                @floatToInt(isize, self.centre.y) - a.y,
                self.colour,
            );
        }
    }
};

fn Point(comptime T: type) type {
    return struct {
        x: T,
        y: T,

        fn add(a: Point(T), b: Point(T)) Point(T) {
            return .{
                .x = a.x + b.x,
                .y = a.y + b.y,
            };
        }
    };
}

fn pow(a: f64, b: f64) f64 {
    return std.math.pow(f64, a, b);
}

fn calculateArc(size: isize, alloc: std.mem.Allocator) ![]Point(isize) {
    var result = std.ArrayList(Point(isize)).init(alloc);
    defer result.deinit();
    var curr: Point(isize) = .{ .x = size, .y = 0 };
    var limit = pow(@intToFloat(f64, size) + 0.5, 2);

    while (curr.x > 0) {
        while (pow(@intToFloat(f64, curr.x), 2) + pow(@intToFloat(f64, curr.y), 2) <= limit) {
            try result.append(curr);
            if (curr.x != curr.y) {
                try result.append(.{ .x = curr.y, .y = curr.x });
            }
            curr.y += 1;
        }
        while (curr.x != 0 and pow(@intToFloat(f64, curr.x), 2) + pow(@intToFloat(f64, curr.y), 2) > limit) {
            curr.x -= 1;
        }
    }

    return result.toOwnedSlice();
}
