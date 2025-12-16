const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const AnchorPoint = @import("anchor_point.zig").AnchorPoint;
const PathDefinition = @import("path_definition.zig").PathDefinition;
const PathIO = @import("path_io.zig").PathIO;

pub const PathRegistry = struct {
    allocator: std.mem.Allocator,
    paths: std.StringHashMap(PathEntry),
    base_path: []const u8,

    const Self = @This();

    const PathEntry = struct {
        anchors: []AnchorPoint,

        pub fn deinit(self: *PathEntry, allocator: std.mem.Allocator) void {
            allocator.free(self.anchors);
        }
    };

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !PathRegistry {
        const expanded_path = try expandPath(allocator, base_path);
        errdefer allocator.free(expanded_path);

        std.fs.cwd().makePath(expanded_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        return .{
            .allocator = allocator,
            .paths = std.StringHashMap(PathEntry).init(allocator),
            .base_path = expanded_path,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.paths.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.paths.deinit();
        self.allocator.free(self.base_path);
    }

    fn stripNul(s: []const u8) []const u8 {
        if (std.mem.indexOfScalar(u8, s, 0)) |i| return s[0..i];
        return s;
    }

    fn validName(s: []const u8) bool {
        if (s.len == 0) return false;
        if (std.mem.indexOfScalar(u8, s, 0) != null) return false;
        return true;
    }

    fn stemFromEntryName(entry_name: []const u8) []const u8 {
        const ext = ".gpath";
        return entry_name[0 .. entry_name.len - ext.len];
    }
    pub fn expandPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
        if (path.len > 0 and path[0] == '~') {
            const home = std.process.getEnvVarOwned(allocator, "HOME") catch |err| blk: {
                // On Windows, try USERPROFILE instead
                if (@import("builtin").os.tag == .windows) {
                    break :blk std.process.getEnvVarOwned(allocator, "USERPROFILE") catch {
                        return error.HomeNotFound;
                    };
                }
                return err;
            };
            defer allocator.free(home);

            if (path.len == 1) {
                // Just "~"
                return try allocator.dupe(u8, home);
            } else if (path[1] == '/') {
                // "~/something"
                return try std.fs.path.join(allocator, &.{ home, path[2..] });
            }
        }

        // No tilde, return as-is
        return try allocator.dupe(u8, path);
    }

    pub fn load(self: *Self) !void {
        var dir = std.fs.cwd().openDir(self.base_path, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) {
                std.debug.print("Path directory not found: {s}\n", .{self.base_path});
                return;
            }
            return err;
        };
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".gpath")) continue;

            var path_buf: [256]u8 = undefined;
            const full_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ self.base_path, entry.name });

            const loaded = PathIO.loadPath(self.allocator, full_path) catch |err| {
                std.debug.print("Failed to load path {s}: {}\n", .{ entry.name, err });
                continue;
            };
            errdefer {
                self.allocator.free(loaded.name);
                self.allocator.free(loaded.anchors);
            }

            const key = stemFromEntryName(entry.name);
            const key_copy = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(key_copy);

            // optionally warn if embedded name differs / is bad
            if (!validName(loaded.name) or !std.mem.eql(u8, loaded.name, key)) {
                std.debug.print(
                    "Warning: {s} has embedded name '{s}' (len={}), using filename stem '{s}'\n",
                    .{ entry.name, loaded.name, loaded.name.len, key },
                );
            }

            try self.paths.put(key_copy, PathEntry{
                .anchors = loaded.anchors,
            });

            self.allocator.free(loaded.name);

            std.debug.print("Asset Path: {s}\n", .{self.base_path});
            std.debug.print("Loaded path: {s}\n", .{entry.name});
            std.debug.print("Struct: {}\n", .{entry});
        }
    }

    pub fn savePath(self: *Self, name: []const u8, anchors: []const AnchorPoint) !void {
        // Ensure the base path exists
        std.fs.cwd().makePath(self.base_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        var filename_buf: [256]u8 = undefined;
        const filename = try std.fmt.bufPrint(&filename_buf, "{s}/{s}.gpath", .{ self.base_path, name });

        try PathIO.savePath(anchors, name, filename);

        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        const anchors_copy = try self.allocator.dupe(AnchorPoint, anchors);
        errdefer self.allocator.free(anchors_copy);

        if (self.paths.fetchRemove(name)) |kv| {
            self.allocator.free(kv.key);
            var value_copy = kv.value;
            value_copy.deinit(self.allocator);
        }

        try self.paths.put(name_copy, PathEntry{
            .anchors = anchors_copy,
        });

        std.debug.print("Saved path: {s}\n", .{name_copy});
    }

    pub fn getPath(self: *const Self, name: []const u8) ?[]const AnchorPoint {
        const entry = self.paths.get(name) orelse return null;
        return entry.anchors;
    }

    pub fn listPaths(self: *const Self, allocator: std.mem.Allocator) ![][]const u8 {
        const names = try allocator.alloc([]const u8, self.paths.count());

        var it = self.paths.keyIterator();
        var i: usize = 0;
        while (it.next()) |key| {
            names[i] = stripNul(key.*);
            i += 1;
        }

        return names;
    }

    pub fn deletePath(self: *Self, name_in: []const u8) !void {
        const name = stripNul(name_in);
        var filename_buf: [256]u8 = undefined;
        const filename = try std.fmt.bufPrint(&filename_buf, "{s}/{s}.gpath", .{ self.base_path, name });
        try std.fs.cwd().deleteFile(filename);

        if (self.paths.fetchRemove(name)) |kv| {
            self.allocator.free(kv.key);
            var kv_value = kv.value;
            kv_value.deinit(self.allocator);
        }

        std.debug.print("Deleted path: {s}\n", .{name});
    }

    pub fn renamePath(self: *Self, old_name: []const u8, new_name: []const u8) !void {
        const entry = self.paths.get(old_name) orelse return error.PathNotFound;
        try self.savePath(new_name, entry.anchors);
        try self.deletePath(old_name);
    }
};
