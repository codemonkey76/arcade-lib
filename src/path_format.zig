const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const AnchorPoint = @import("anchor_point.zig").AnchorPoint;
const HandleMode = @import("anchor_point.zig").HandleMode;

pub const MAGIC: [4]u8 = .{ 'G', 'P', 'T', 'H' };
pub const VERSION: u8 = 2;

pub const Header = packed struct {
    magic: u32,
    version: u8,
    name_length: u8,
    point_count: u16,
    reserved: u64,

    pub fn setMagic(self: *@This()) void {
        self.magic = @bitCast(MAGIC);
    }

    pub fn checkMagic(self: @This()) bool {
        const magic_bytes: [4]u8 = @bitCast(self.magic);
        return std.mem.eql(u8, &magic_bytes, &MAGIC);
    }
};

pub const Point = packed struct {
    x_bits: u32,
    y_bits: u32,

    pub fn getVec2(self: @This()) Vec2 {
        return Vec2{
            .x = @bitCast(self.x_bits),
            .y = @bitCast(self.y_bits),
        };
    }

    pub fn fromVec2(vec: Vec2) Point {
        return .{
            .x_bits = @bitCast(vec.x),
            .y_bits = @bitCast(vec.y),
        };
    }
};

pub const AnchorPointBinary = packed struct {
    pos: Point,
    handle_in: Point,
    handle_out: Point,
    has_handle_in: u8,
    has_handle_out: u8,
    mode: u8,
    reserved: u8,
    const Self = @This();

    pub fn fromAnchorPoint(anchor: AnchorPoint) Self {
        return .{
            .pos = Point.fromVec2(anchor.pos),
            .handle_in = if (anchor.handle_in) |h| Point.fromVec2(h) else Point.fromVec2(.{ .x = 0, .y = 0 }),
            .handle_out = if (anchor.handle_out) |h| Point.fromVec2(h) else Point.fromVec2(.{ .x = 0, .y = 0 }),
            .has_handle_in = if (anchor.handle_in != null) 1 else 0,
            .has_handle_out = if (anchor.handle_out != null) 1 else 0,
            .mode = @intFromEnum(anchor.mode),
            .reserved = 0,
        };
    }

    pub fn toAnchorPoint(self: Self) AnchorPoint {
        return .{
            .pos = self.pos.getVec2(),
            .handle_in = if (self.has_handle_in != 0) self.handle_in.getVec2() else null,
            .handle_out = if (self.has_handle_out != 0) self.handle_out.getVec2() else null,
            .mode = @enumFromInt(self.mode),
        };
    }
};
