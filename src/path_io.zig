const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const PathDefinition = @import("path_definition.zig").PathDefinition;
const PathFormat = @import("path_format.zig");
const AnchorPoint = @import("anchor_point.zig").AnchorPoint;

pub const PathIO = struct {
    pub fn savePath(path: []const AnchorPoint, name: []const u8, filename: []const u8) !void {
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var header = PathFormat.Header{
            .magic = undefined,
            .version = PathFormat.VERSION,
            .name_length = @intCast(name.len),
            .point_count = @intCast(path.len),
            .reserved = 0,
        };
        header.setMagic();

        try file.writeAll(std.mem.asBytes(&header));
        try file.writeAll(name);

        for (path) |anchor| {
            const anchor_binary = PathFormat.AnchorPointBinary.fromAnchorPoint(anchor);
            try file.writeAll(std.mem.asBytes(&anchor_binary));
        }
    }

    pub const LoadedPath = struct {
        name: []u8,
        anchors: []AnchorPoint,

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.free(self.anchors);
        }
    };

    pub fn loadPath(allocator: std.mem.Allocator, filename: []const u8) !LoadedPath {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var header: PathFormat.Header = undefined;
        const header_bytes = try file.readAll(std.mem.asBytes(&header));
        if (header_bytes != @sizeOf(PathFormat.Header)) return error.InvalidFile;

        if (!header.checkMagic()) return error.InvalidMagic;
        if (header.version != PathFormat.VERSION) return error.UnsupportedVersion;

        const name = try allocator.alloc(u8, header.name_length);
        errdefer allocator.free(name);

        const name_bytes = try file.readAll(name);
        if (name_bytes != header.name_length) return error.InvalidName;

        const anchors = try allocator.alloc(AnchorPoint, header.point_count);
        errdefer allocator.free(anchors);

        for (anchors) |*anchor| {
            var anchor_binary: PathFormat.AnchorPointBinary = undefined;
            const anchor_bytes = try file.readAll(std.mem.asBytes(&anchor_binary));
            if (anchor_bytes != @sizeOf(PathFormat.AnchorPointBinary)) return error.InvalidPoint;
            anchor.* = anchor_binary.toAnchorPoint();
        }

        return LoadedPath{
            .name = name,
            .anchors = anchors,
        };
    }
};
