const Vec2 = @import("vec2.zig").Vec2;

pub const HandleMode = enum {
    corner, // handles move independently
    smooth, // handles are mirrored (opposite direction, same length)
    aligned, // handles are opposite direction but can differ in length
};

pub const AnchorPoint = struct {
    pos: Vec2,
    handle_in: ?Vec2,
    handle_out: ?Vec2,
    mode: HandleMode,

    const Self = @This();

    /// Get absolute position of the incoming handle
    pub fn getHandleInPos(self: *const Self) ?Vec2 {
        const h = self.handle_in orelse return null;
        return .{
            .x = self.pos.x + h.x,
            .y = self.pos.y + h.y,
        };
    }

    /// Get absolute position of the outgoing handle
    pub fn getHandleOutPos(self: *const Self) ?Vec2 {
        const h = self.handle_out orelse return null;
        return .{
            .x = self.pos.x + h.x,
            .y = self.pos.y + h.y,
        };
    }

    /// Set the outgoing handle, respecting the handle mode
    pub fn setHandleOut(self: *@This(), handle: Vec2) void {
        self.handle_out = handle;

        switch (self.mode) {
            .smooth => {
                // Mirror the handle
                self.handle_in = Vec2{
                    .x = -handle.x,
                    .y = -handle.y,
                };
            },
            .aligned => {
                // Keep opposite direction but preserve length if handle_in exists
                if (self.handle_in) |h_in| {
                    const len = @sqrt(h_in.x * h_in.x + h_in.y * h_in.y);
                    const out_len = @sqrt(handle.x * handle.x + handle.y * handle.y);
                    if (out_len > 0.0001) {
                        const scale = len / out_len;
                        self.handle_in = Vec2{
                            .x = -handle.x * scale,
                            .y = -handle.y * scale,
                        };
                    }
                }
            },
            .corner => {
                // Handles are independent
            },
        }
    }

    /// Set the incoming handle, respecting the handle mode
    pub fn setHandleIn(self: *@This(), handle: Vec2) void {
        self.handle_in = handle;

        switch (self.mode) {
            .smooth => {
                // Mirror the handle
                self.handle_out = Vec2{
                    .x = -handle.x,
                    .y = -handle.y,
                };
            },
            .aligned => {
                // Keep opposite direction but preserve length if handle_out exists
                if (self.handle_out) |h_out| {
                    const len = @sqrt(h_out.x * h_out.x + h_out.y * h_out.y);
                    const in_len = @sqrt(handle.x * handle.x + handle.y * handle.y);
                    if (in_len > 0.0001) {
                        const scale = len / in_len;
                        self.handle_out = Vec2{
                            .x = -handle.x * scale,
                            .y = -handle.y * scale,
                        };
                    }
                }
            },
            .corner => {
                // Handles are independent
            },
        }
    }
};
