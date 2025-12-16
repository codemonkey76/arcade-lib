# Arcade Lib

A lightweight Zig library for creating and managing Bézier curve paths in 2D arcade-style games. Designed for smooth enemy movement patterns, bullet trajectories, and any path-based game mechanics.

## Overview

Arcade Lib provides a complete solution for working with Bézier curves in games:
- **Anchor-based path editing** with smooth, aligned, and corner modes
- **Efficient binary format** for storing paths
- **Path registry** for managing multiple named paths
- **Normalized coordinates** (0-1 range) for resolution-independent paths
- **Cubic Bézier curves** for smooth, professional-looking motion

## Features

- **Flexible Path Definition**
  - Create paths from anchor points with control handles
  - Support for corner, smooth, and aligned handle modes
  - Automatic conversion between anchor points and Bézier control points
  - Evaluate position at any point along the path (0.0 to 1.0)

- **Path Storage**
  - Binary `.gpath` format for efficient storage
  - Human-readable path names
  - Version-tracked format for future compatibility
  - Automatic path discovery and loading

- **Path Management**
  - Registry system for managing multiple paths
  - Create, load, save, rename, and delete paths
  - Path names as keys for easy lookup
  - Automatic home directory expansion (`~` support)

- **Game Integration**
  - Zero external dependencies
  - Simple, allocation-aware API
  - Works with any 2D coordinate system
  - Easy to integrate with existing game engines

## Installation

### As a Zig Package

Add to your `build.zig.zon`:
```zig
.dependencies = .{
    .arcade_lib = .{
        .url = "git+https://github.com/codemonkey76/arcade-lib#main",
        .hash = "1220...", // Zig will provide the hash
    },
},
```

Then in your `build.zig`:
```zig
const arcade_lib_dep = b.dependency("arcade_lib", .{
    .target = target,
});
const arcade_lib_mod = arcade_lib_dep.module("arcade_lib");

exe.root_module.addImport("arcade_lib", arcade_lib_mod);
```

## Quick Start

### Creating and Using Paths
```zig
const std = @import("std");
const arcade = @import("arcade_lib");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize path registry
    var paths = try arcade.PathRegistry.init(allocator, "assets/paths");
    defer paths.deinit();

    // Load all paths from directory
    try paths.load();

    // Create a new path
    const anchors = [_]arcade.AnchorPoint{
        .{
            .pos = .{ .x = 0.1, .y = 0.1 },
            .handle_in = null,
            .handle_out = .{ .x = 0.2, .y = 0.0 },
            .mode = .smooth,
        },
        .{
            .pos = .{ .x = 0.5, .y = 0.5 },
            .handle_in = .{ .x = -0.2, .y = 0.0 },
            .handle_out = .{ .x = 0.2, .y = 0.0 },
            .mode = .smooth,
        },
        .{
            .pos = .{ .x = 0.9, .y = 0.9 },
            .handle_in = .{ .x = -0.2, .y = 0.0 },
            .handle_out = null,
            .mode = .smooth,
        },
    };

    // Save the path
    try paths.savePath("enemy_wave_1", &anchors);

    // Later, retrieve and use the path
    const path_data = paths.getPath("enemy_wave_1") orelse return;
    
    // Convert to control points for rendering
    const control_points = try arcade.PathDefinition.fromAnchorPoints(
        allocator,
        path_data,
    );
    defer allocator.free(control_points);

    const path = arcade.PathDefinition{ .control_points = control_points };

    // Animate along the path
    var t: f32 = 0.0;
    while (t <= 1.0) : (t += 0.01) {
        const pos = path.getPosition(t);
        // Use pos.x and pos.y to position your game object
        std.debug.print("Position: ({d:.2}, {d:.2})\n", .{ pos.x, pos.y });
    }
}
```

### Handle Modes
```zig
// Corner mode - handles move independently
const corner_anchor = arcade.AnchorPoint{
    .pos = .{ .x = 0.5, .y = 0.5 },
    .handle_in = .{ .x = -0.1, .y = 0.0 },
    .handle_out = .{ .x = 0.0, .y = 0.1 },
    .mode = .corner, // Handles are independent
};

// Smooth mode - handles are mirrored
const smooth_anchor = arcade.AnchorPoint{
    .pos = .{ .x = 0.5, .y = 0.5 },
    .handle_in = .{ .x = -0.1, .y = 0.0 },
    .handle_out = .{ .x = 0.1, .y = 0.0 }, // Mirrored
    .mode = .smooth, // Handles stay opposite and same length
};

// Aligned mode - handles are opposite but can differ in length
const aligned_anchor = arcade.AnchorPoint{
    .pos = .{ .x = 0.5, .y = 0.5 },
    .handle_in = .{ .x = -0.1, .y = 0.0 },
    .handle_out = .{ .x = 0.2, .y = 0.0 }, // Opposite direction, different length
    .mode = .aligned, // Handles stay opposite but can scale independently
};
```

### Game Integration Example
```zig
const Enemy = struct {
    path_def: arcade.PathDefinition,
    path_progress: f32, // 0.0 to 1.0
    speed: f32, // Units per second
    
    pub fn update(self: *Enemy, dt: f32) void {
        // Advance along path
        self.path_progress += self.speed * dt;
        
        if (self.path_progress >= 1.0) {
            // Path complete - loop or despawn
            self.path_progress = 0.0;
        }
    }
    
    pub fn getPosition(self: Enemy, screen_width: f32, screen_height: f32) struct { x: f32, y: f32 } {
        const pos = self.path_def.getPosition(self.path_progress);
        return .{
            .x = pos.x * screen_width,
            .y = pos.y * screen_height,
        };
    }
};
```

## API Reference

### Core Types

#### `Vec2`
```zig
pub const Vec2 = struct {
    x: f32,
    y: f32,
};
```

#### `AnchorPoint`
```zig
pub const AnchorPoint = struct {
    pos: Vec2,              // Anchor position (0-1 normalized)
    handle_in: ?Vec2,       // Incoming handle (relative to pos)
    handle_out: ?Vec2,      // Outgoing handle (relative to pos)
    mode: HandleMode,       // Corner, smooth, or aligned
    
    // Get absolute handle positions
    pub fn getHandleInPos(self: *const Self) ?Vec2;
    pub fn getHandleOutPos(self: *const Self) ?Vec2;
    
    // Set handles with automatic mode handling
    pub fn setHandleIn(self: *Self, handle: Vec2) void;
    pub fn setHandleOut(self: *Self, handle: Vec2) void;
};
```

#### `HandleMode`
```zig
pub const HandleMode = enum {
    corner,   // Handles move independently
    smooth,   // Handles are mirrored (opposite direction, same length)
    aligned,  // Handles are opposite but can differ in length
};
```

#### `PathDefinition`
```zig
pub const PathDefinition = struct {
    control_points: []const Vec2,
    
    // Get position along path (t: 0.0 to 1.0)
    pub fn getPosition(self: Self, t: f32) Vec2;
    
    // Get start/end positions
    pub fn getStartPosition(self: Self) Vec2;
    pub fn getEndPosition(self: Self) Vec2;
    
    // Convert anchor points to Bézier control points
    pub fn fromAnchorPoints(allocator: Allocator, anchors: []const AnchorPoint) ![]Vec2;
    
    // Convert simple points to Bézier (using Catmull-Rom)
    pub fn fromPoints(allocator: Allocator, points: []const Vec2) ![]Vec2;
    
    // Get segment count and individual segments
    pub fn getSegmentCount(self: Self) usize;
    pub fn getSegment(self: Self, index: usize) ?BezierSegment;
};
```

#### `PathRegistry`
```zig
pub const PathRegistry = struct {
    // Create registry pointing to a directory
    pub fn init(allocator: Allocator, base_path: []const u8) !PathRegistry;
    pub fn deinit(self: *Self) void;
    
    // Load all .gpath files from directory
    pub fn load(self: *Self) !void;
    
    // Path management
    pub fn savePath(self: *Self, name: []const u8, anchors: []const AnchorPoint) !void;
    pub fn getPath(self: *const Self, name: []const u8) ?[]const AnchorPoint;
    pub fn deletePath(self: *Self, name: []const u8) !void;
    pub fn renamePath(self: *Self, old_name: []const u8, new_name: []const u8) !void;
    
    // List all path names
    pub fn listPaths(self: *const Self, allocator: Allocator) ![][]const u8;
};
```

### File Format

Paths are stored in a binary `.gpath` format:
```
Header (16 bytes):
- magic: "GPTH" (4 bytes)
- version: 2 (1 byte)
- name_length: length of embedded name (1 byte)
- point_count: number of anchor points (2 bytes)
- reserved: (8 bytes)

Name: UTF-8 string (name_length bytes)

Anchor Points (28 bytes each):
- pos: Vec2 (8 bytes)
- handle_in: Vec2 (8 bytes)
- handle_out: Vec2 (8 bytes)
- has_handle_in: bool (1 byte)
- has_handle_out: bool (1 byte)
- mode: HandleMode (1 byte)
- reserved: (1 byte)
```

## Path Coordinates

All coordinates are **normalized** (0.0 to 1.0):
- `(0.0, 0.0)` = top-left
- `(1.0, 1.0)` = bottom-right
- `(0.5, 0.5)` = center

This makes paths resolution-independent. Scale them to your game's coordinate system:
```zig
const pos = path.getPosition(t);
const screen_x = pos.x * screen_width;
const screen_y = pos.y * screen_height;
```

## Best Practices

### Path Creation
```zig
// Use smooth mode for natural curves
const smooth_curve = arcade.AnchorPoint{
    .pos = .{ .x = 0.5, .y = 0.5 },
    .handle_in = .{ .x = -0.2, .y = 0.0 },
    .handle_out = .{ .x = 0.2, .y = 0.0 },
    .mode = .smooth,
};

// Use corner mode for sharp turns
const sharp_turn = arcade.AnchorPoint{
    .pos = .{ .x = 0.5, .y = 0.5 },
    .handle_in = .{ .x = -0.1, .y = 0.0 },
    .handle_out = .{ .x = 0.0, .y = 0.1 },
    .mode = .corner,
};
```

### Memory Management
```zig
// Always free control points after use
const control_points = try arcade.PathDefinition.fromAnchorPoints(
    allocator,
    anchors,
);
defer allocator.free(control_points);

// Registry manages its own memory
var paths = try arcade.PathRegistry.init(allocator, "assets/paths");
defer paths.deinit(); // Cleans up all loaded paths
```

### Path Storage
```zig
// Use consistent naming conventions
try paths.savePath("enemy_wave_1", &anchors);
try paths.savePath("boss_entry", &boss_path);
try paths.savePath("bullet_spiral", &spiral);

// Keep paths in a dedicated directory
var paths = try arcade.PathRegistry.init(allocator, "assets/paths");
```

## Tools

Use [Path Sketcher](https://github.com/codemonkey76/path-sketcher) for visual path editing:
- Visual Bézier curve editor
- Real-time preview
- Save directly to `.gpath` format
- Works seamlessly with arcade-lib

## Examples

See the [examples](examples/) directory for:
- Basic path creation and usage
- Enemy movement patterns
- Bullet trajectories
- Boss attack patterns

## Testing
```bash
# Run all tests
zig build test
```

## Contributing

Contributions are welcome! Please open an issue or PR.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Related Projects

- [Path Sketcher](https://github.com/codemonkey76/path-sketcher) - Visual path editor
- [Zalaga](https://github.com/codemonkey76/zalaga) - Example game using arcade-lib
- [zig-arcade-engine](https://github.com/codemonkey76/zig-arcade-engine) - 2D game engine

## Acknowledgments

- Built with [Zig](https://ziglang.org/)
- Inspired by classic arcade games
- Bézier curve math based on standard cubic Bézier formulas

## Support

For questions or issues, please [open an issue](https://github.com/codemonkey76/arcade-lib/issues) on GitHub.
