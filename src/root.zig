pub const Vec2 = @import("vec2.zig").Vec2;
pub const PathFormat = @import("path_format.zig");

pub const PathDefinition = @import("path_definition.zig").PathDefinition;
pub const PathRegistry = @import("path_registry.zig").PathRegistry;
pub const BezierSegment = @import("bezier_segment.zig").BezierSegment;
pub const AnchorPoint = @import("anchor_point.zig").AnchorPoint;
pub const HandleMode = @import("anchor_point.zig").HandleMode;

pub const Path = struct {
    pub const savePath = @import("path_io.zig").PathIO.savePath;
    pub const loadPath = @import("path_io.zig").PathIO.loadPath;
};
