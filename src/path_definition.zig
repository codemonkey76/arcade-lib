const Vec2 = @import("vec2.zig").Vec2;
const std = @import("std");
const BezierSegment = @import("bezier_segment.zig").BezierSegment;
const AnchorPoint = @import("anchor_point.zig").AnchorPoint;

pub const PathDefinition = struct {
    control_points: []const Vec2,
    const Self = @This();

    pub fn getSegmentCount(self: Self) usize {
        return (self.control_points.len - 1) / 3;
    }

    pub fn getSegment(self: Self, index: usize) ?BezierSegment {
        if (index >= self.getSegmentCount()) return null;

        const base = index * 3;

        return BezierSegment{
            .p0 = self.control_points[base],
            .p1 = self.control_points[base + 1],
            .p2 = self.control_points[base + 2],
            .p3 = self.control_points[base + 3],
        };
    }
    fn linearInterpolation(p0: Vec2, p1: Vec2, t: f32) Vec2 {
        return Vec2{
            .x = p0.x + (p1.x - p0.x) * t,
            .y = p0.y + (p1.y - p0.y) * t,
        };
    }

    fn quadraticBezier(p0: Vec2, p1: Vec2, p2: Vec2, t: f32) Vec2 {
        const mt = 1.0 - t;
        return Vec2{
            .x = mt * mt * p0.x + 2.0 * mt * t * p1.x + t * t * p2.x,
            .y = mt * mt * p0.y + 2.0 * mt * t * p1.y + t * t * p2.y,
        };
    }

    fn cubicBezier(p0: Vec2, p1: Vec2, p2: Vec2, p3: Vec2, t: f32) Vec2 {
        const t2 = t * t;
        const t3 = t2 * t;
        const mt = 1.0 - t;
        const mt2 = mt * mt;
        const mt3 = mt2 * mt;

        return Vec2{
            .x = mt3 * p0.x + 3.0 * mt2 * t * p1.x + 3.0 * mt * t2 * p2.x + t3 * p3.x,
            .y = mt3 * p0.y + 3.0 * mt2 * t * p1.y + 3.0 * mt * t2 * p2.y + t3 * p3.y,
        };
    }

    pub fn getPosition(self: @This(), t: f32) Vec2 {
        const clamped_t = @max(0.0, @min(1.0, t));

        switch (self.control_points.len) {
            0 => return Vec2{ .x = 0, .y = 0 },
            1 => return self.control_points[0],
            2 => return linearInterpolation(self.control_points[0], self.control_points[1], clamped_t),
            3 => return quadraticBezier(self.control_points[0], self.control_points[1], self.control_points[2], clamped_t),
            else => {
                // Cubic Bézier for 4+ points
                const seg_count = self.getSegmentCount();
                if (seg_count == 0) return Vec2{ .x = 0, .y = 0 };

                const segment_count_f = @as(f32, @floatFromInt(seg_count));
                const segment_t = clamped_t * segment_count_f;
                const segment_index = @as(usize, @intFromFloat(@floor(segment_t)));
                const local_t = if (segment_index >= seg_count) 1.0 else segment_t - @floor(segment_t);
                const index = if (segment_index >= seg_count) seg_count - 1 else segment_index;

                const segment = self.getSegment(index) orelse return Vec2{ .x = 0, .y = 0 };
                return segment.evaluate(local_t);
            },
        }
    }

    pub fn fromAnchorPoints(allocator: std.mem.Allocator, anchors: []const AnchorPoint) ![]Vec2 {
        if (anchors.len == 0) return &[_]Vec2{};
        if (anchors.len == 1) return try allocator.dupe(Vec2, &[_]Vec2{anchors[0].pos});

        // Each segment between two anchors needs 4 control points p0, p2, p2, p3
        // With N anchors, we have N-1 segments
        // Total control points: 4 + (N-2) * 3 = 1 + (N-1)*3
        const segment_count = anchors.len - 1;
        const control_count = 1 + segment_count * 3;
        var control_points = try allocator.alloc(Vec2, control_count);

        // First anchor's position
        control_points[0] = anchors[0].pos;

        for (0..segment_count) |i| {
            const anchor_a = anchors[i];
            const anchor_b = anchors[i + 1];

            const base_idx = 1 + i * 3;

            // Control point 1: anchor_a's outgoing handle (or anchor_a.pos if no handle)
            control_points[base_idx] = if (anchor_a.handle_out) |h|
                Vec2{ .x = anchor_a.pos.x + h.x, .y = anchor_a.pos.y + h.y }
            else
                anchor_a.pos;

            // Control point 2: anchor_b's incoming handle (or anchor_b.pos if no handle)
            control_points[base_idx + 1] = if (anchor_b.handle_in) |h|
                Vec2{ .x = anchor_b.pos.x + h.x, .y = anchor_b.pos.y + h.y }
            else
                anchor_b.pos;

            // Control point 3: anchor_b's position
            control_points[base_idx + 2] = anchor_b.pos;
        }

        return control_points;
    }

    /// Convert a sequence of points into cubic Bezier control points
    /// using Catmull-Rom spline to Bezier conversion
    pub fn fromPoints(allocator: std.mem.Allocator, points: []const Vec2) ![]Vec2 {
        if (points.len == 0) return &[_]Vec2{};
        if (points.len == 1) return try allocator.dupe(Vec2, points);
        if (points.len == 2) {
            // Just a line - create a degenerate bezier
            return try allocator.dupe(Vec2, &[_]Vec2{ points[0], points[0], points[1], points[1] });
        }

        // For 3+ points, generate cubic bezier segments
        const segment_count = points.len - 1;
        var control_points = try allocator.alloc(Vec2, 1 + segment_count * 3);

        control_points[0] = points[0];

        for (0..segment_count) |i| {
            const p0 = if (i == 0) points[0] else points[i - 1];
            const p1 = points[i];
            const p2 = points[i + 1];
            const p3 = if (i + 2 < points.len) points[i + 2] else points[i + 1];

            // Catmull-Rom to Bezier conversion
            const base_idx = 1 + i * 3;
            control_points[base_idx] = Vec2{
                .x = p1.x + (p2.x - p0.x) / 6.0,
                .y = p1.y + (p2.y - p0.y) / 6.0,
            };
            control_points[base_idx + 1] = Vec2{
                .x = p2.x - (p3.x - p1.x) / 6.0,
                .y = p2.y - (p3.y - p1.y) / 6.0,
            };
            control_points[base_idx + 2] = p2;
        }

        return control_points;
    }
    pub fn getStartPosition(self: @This()) Vec2 {
        if (self.control_points.len == 0) return Vec2{ .x = 0, .y = 0 };
        return self.control_points[0];
    }

    pub fn getEndPosition(self: @This()) Vec2 {
        if (self.control_points.len == 0) return Vec2{ .x = 0, .y = 0 };
        const seg_count = self.getSegmentCount();
        if (seg_count == 0) return self.control_points[0];
        if (seg_count == 1) {
            return self.control_points[3];
        } else {
            return self.control_points[self.control_points.len - 1];
        }
    }
};
