const Vec2 = @import("vec2.zig").Vec2;

/// A single bezier curve segment (cubic bezier)
pub const BezierSegment = struct {
    p0: Vec2,
    p1: Vec2,
    p2: Vec2,
    p3: Vec2,

    /// Evaluate a bezier at time t (0.0 to 1.0)
    pub fn evaluate(self: @This(), t: f32) Vec2 {
        const t2 = t * t;
        const t3 = t2 * t;
        const mt = 1.0 - t;
        const mt2 = mt * mt;
        const mt3 = mt2 * mt;

        return Vec2{
            .x = mt3 * self.p0.x + 3.0 * mt2 * t * self.p1.x + 3.0 * mt * t2 * self.p2.x + t3 * self.p3.x,
            .y = mt3 * self.p0.y + 3.0 * mt2 * t * self.p1.y + 3.0 * mt * t2 * self.p2.y + t3 * self.p3.y,
        };
    }
};
