const std = @import("std");
const zigimg = @import("zigimg");
const Rgba32 = @import("drawer.zig").Rgba32;

const Drawer = @import("drawer.zig").Drawer;

pub const Model = struct {
    const Self = @This();

    width: isize,
    height: isize,
    circles: []Circle,
    lines: []Line,

    pub fn new(circles: []Circle, lines: []Line, width: isize, height: isize) Self {
        return .{
            .width = width,
            .height = height,
            .circles = circles,
            .lines = lines,
        };
    }

    pub fn iterate(self: *Self) void {
        for (self.circles) |*c| {
            c.iterate(self.width, self.height);
        }

        for (self.circles) |*c1, ind1| {
            for (self.circles[ind1 + 1 ..]) |*c2| {
                c1.collideCircle(c2);
            }

            for (self.lines) |line| {
                c1.collideLine(line);
            }
        }
    }

    pub fn draw(self: Self, drawer: *Drawer) void {
        for (self.lines) |l| {
            l.draw(drawer);
        }
        for (self.circles) |c| {
            c.draw(drawer);
        }
        for (self.circles) |c, i| {
            for (self.circles[0..i]) |c2| {
                c.drawMidpoint(c2, drawer);
            }
        }
    }
};

pub const Direction = enum {
    vertical,
    horizontal,
};

pub const Line = struct {
    const Self = @This();

    const colour = Rgba32.new(255, 0, 0, 255);

    direction: Direction,
    start: isize,
    end: isize,
    at: isize,

    pub fn new(direction: Direction, start: isize, end: isize, at: isize) Self {
        return .{
            .direction = direction,
            .start = start,
            .end = end,
            .at = at,
        };
    }

    fn draw(self: Self, drawer: *Drawer) void {
        var p: Point(isize) = switch (self.direction) {
            .vertical => .{ .x = self.at, .y = self.start },
            .horizontal => .{ .x = self.start, .y = self.at },
        };
        var d: Point(isize) = switch (self.direction) {
            .vertical => .{ .x = 0, .y = 1 },
            .horizontal => .{ .x = 1, .y = 0 },
        };
        var end: Point(isize) = switch (self.direction) {
            .vertical => .{ .x = self.at, .y = self.end },
            .horizontal => .{ .x = self.end, .y = self.at },
        };
        while (!p.eql(end)) : (p = p.add(d)) {
            drawer.place(p.x, p.y, colour);
        }
    }
};

pub const Circle = struct {
    const Self = @This();

    colour: Rgba32,
    velocity: Point(f64),
    centre: Point(f64),
    radius: f64,
    arc: []Point(isize),

    pub fn new(w: isize, h: isize, rng: *std.rand.DefaultPrng, alloc: std.mem.Allocator) !Self {
        var angle = rng.random().float(f64) * 2 * std.math.pi;
        var radius = @mod(rng.random().int(isize), 25) + 10;
        return Self{
            .colour = Rgba32.new(
                255,
                255,
                0,
                255,
            ),
            .velocity = .{
                .x = @sin(angle),
                .y = @cos(angle),
            },
            .centre = .{
                .x = 5 + @intToFloat(f64, radius) + rng.random().float(f64) * @intToFloat(f64, w - (2 * (5 + radius))),
                .y = 5 + @intToFloat(f64, radius) + rng.random().float(f64) * @intToFloat(f64, h - (2 * (5 + radius))),
            },
            .radius = @intToFloat(f64, radius),
            .arc = try calculateArc(radius, alloc),
        };
    }

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        alloc.free(self.arc);
    }

    pub fn hasCollisionCircle(a: Self, b: Self) bool {
        var distBetweenCirclesSquared = pow(a.centre.x - b.centre.x, 2) + pow(a.centre.y - b.centre.y, 2);
        var radiiSquared = pow(a.radius + b.radius, 2);
        return distBetweenCirclesSquared < radiiSquared;
    }

    pub fn collideCircle(a: *Self, b: *Self) void {
        if (!a.hasCollisionCircle(b.*)) {
            return;
        }

        var midPoint = a.adjustedMidpoint(b.*);
        a.centre = midPoint.add(a.centre.sub(midPoint).normalised().mul(a.radius));
        b.centre = midPoint.add(b.centre.sub(midPoint).normalised().mul(b.radius));

        a.velocity = a.velocity.neg();
        a.velocity = b.velocity.neg();
    }

    fn collideLine(self: *Self, line: Line) void {
        switch (line.direction) {
            .horizontal => {
                if (self.centre.y - self.radius < @intToFloat(f64, line.at) and self.centre.y + self.radius > @intToFloat(f64, line.at)) {
                    if (self.velocity.y > 0) {
                        self.centre.y = @intToFloat(f64, line.at) - self.radius;
                    } else {
                        self.centre.y = @intToFloat(f64, line.at) + self.radius;
                    }
                    self.velocity.y = -self.velocity.y;
                }
            },
            .vertical => {
                if (self.centre.x - self.radius < @intToFloat(f64, line.at) and self.centre.x + self.radius > @intToFloat(f64, line.at)) {
                    if (self.velocity.x > 0) {
                        self.centre.x = @intToFloat(f64, line.at) - self.radius;
                    } else {
                        self.centre.x = @intToFloat(f64, line.at) + self.radius;
                    }
                    self.velocity.x = -self.velocity.x;
                }
            },
        }
    }

    fn iterate(self: *Self, width: isize, height: isize) void {
        self.centre = self.centre.add(self.velocity);
        self.centre.x = @mod(self.centre.x, @intToFloat(f64, width));
        self.centre.y = @mod(self.centre.y, @intToFloat(f64, height));
    }

    fn adjustedMidpoint(a: Self, b: Self) Point(f64) {
        var expectedRadius = a.radius + b.radius;
        var aProp = a.radius / expectedRadius;
        var ab = b.centre.sub(a.centre);
        var abWeighted = ab.mul(aProp);
        var result = a.centre.add(abWeighted);
        return result;
    }

    fn drawMidpoint(a: Self, b: Self, drawer: *Drawer) void {
        var midPoint = a.adjustedMidpoint(b);

        var i: isize = 0;
        while (i < 9) : (i += 2) {
            drawer.place(
                @floatToInt(isize, midPoint.x) + @rem(i, 3) - 1,
                @floatToInt(isize, midPoint.y) + @divTrunc(i, 3) - 1,
                Rgba32.red(),
            );
        }
    }

    fn draw(self: Self, drawer: *Drawer) void {
        var x = @floatToInt(isize, self.centre.x);
        var y = @floatToInt(isize, self.centre.y);

        var i: isize = 0;
        while (i < 9) : (i += 1) {
            drawer.place(
                x + @rem(i, 3) - 1,
                y + @divTrunc(i, 3) - 1,
                Rgba32.new(0, 255, 0, 255),
            );
        }

        for (self.arc) |a| {
            drawer.place(
                x + a.x,
                y + a.y,
                self.colour,
            );

            drawer.place(
                x - a.x,
                y + a.y,
                self.colour,
            );

            drawer.place(
                x + a.x,
                y - a.y,
                self.colour,
            );

            drawer.place(
                x - a.x,
                y - a.y,
                self.colour,
            );
        }
    }
};

fn Point(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

        fn add(a: Self, b: Self) Self {
            return .{
                .x = a.x + b.x,
                .y = a.y + b.y,
            };
        }

        fn sub(a: Self, b: Self) Self {
            return .{
                .x = a.x - b.x,
                .y = a.y - b.y,
            };
        }

        fn neg(self: Self) Self {
            return .{
                .x = -self.x,
                .y = -self.y,
            };
        }

        fn eql(a: Self, b: Self) bool {
            return std.meta.eql(a, b);
        }

        fn normalised(self: Self) Self {
            var total = std.math.fabs(self.x) + std.math.fabs(self.y);
            return .{
                .x = self.x / total,
                .y = self.y / total,
            };
        }

        fn mul(self: Self, mult: T) Self {
            return .{
                .x = self.x * mult,
                .y = self.y * mult,
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

test "can find adjusted midpoint of circles" {
    var a = Circle{
        .colour = undefined,
        .velocity = undefined,
        .centre = .{ .x = 0, .y = 0 },
        .radius = 1,
        .arc = undefined,
    };
    var b = Circle{
        .colour = undefined,
        .velocity = undefined,
        .centre = .{ .x = 4, .y = 4 },
        .radius = 3,
        .arc = undefined,
    };

    try std.testing.expectEqual(Point(f64){ .x = 1, .y = 1 }, a.adjustedMidpoint(b));
}

test "collisions move circles the correct amounts" {
    var a = Circle{
        .colour = undefined,
        .velocity = undefined,
        .centre = .{ .x = 1, .y = 0 },
        .radius = 5,
        .arc = undefined,
    };
    var b = Circle{
        .colour = undefined,
        .velocity = undefined,
        .centre = .{ .x = 9, .y = 0 },
        .radius = 5,
        .arc = undefined,
    };

    try std.testing.expectEqual(Point(f64){ .x = 5, .y = 0 }, a.adjustedMidpoint(b));
    Circle.collideCircle(&a, &b);
    try std.testing.expectEqual(Point(f64){ .x = 0, .y = 0 }, a.centre);
    try std.testing.expectEqual(Point(f64){ .x = 10, .y = 0 }, b.centre);
}
