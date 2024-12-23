const std = @import("std");
const rl = @import("raylib");

const table_image_data = @embedFile("./assets/table-light.jpg");

fn Grid(comptime rows: usize, comptime cols: usize) type {
    return struct {
        posX: i32,
        posY: i32,
        tile_width: i32,
        tile_height: i32,
        gap: i32,
        // like some text in a book, left to right, top to bottom
        tiles: [rows * cols]?Tile,

        fn width(self: Grid(rows, cols)) i32 {
            return self.tile_width - self.gap;
        }

        fn height(self: Grid(rows, cols)) i32 {
            return self.tile_height - self.gap;
        }

        fn draw(
            self: Grid(rows, cols),
            color: rl.Color,
        ) void {
            // draw the grid background
            for (0..rows) |row| {
                for (0..cols) |col| {
                    const r: i32 = @intCast(row);
                    const c: i32 = @intCast(col);
                    rl.drawRectangle(
                        self.posX + c * self.tile_width,
                        self.posY + r * self.tile_height,
                        self.width(),
                        self.height(),
                        color,
                    );
                }
            }

            // draw the tiles on top
            for (self.tiles) |maybe_tile| {
                if (maybe_tile) |tile| {
                    tile.draw(rl.Color.white, rl.Color.light_gray, rl.Color.black);
                }
            }
        }

        fn coords(self: Grid(rows, cols), pos: rl.Vector2) struct { x: i32, y: i32 } {
            const posX: i32 = @intFromFloat(pos.x);
            const posY: i32 = @intFromFloat(pos.y);
            const snapX: i32 = @divFloor((posX - self.posX), self.tile_width);
            const snapY: i32 = @divFloor((posY - self.posY), self.tile_height);
            return .{ .x = snapX, .y = snapY };
        }

        fn snap(self: Grid(rows, cols), pos: rl.Vector2) rl.Vector2 {
            const coord = self.coords(pos);
            const snapX: i32 = coord.x * self.tile_width + self.posX;
            const snapY: i32 = coord.y * self.tile_height + self.posY;
            return rl.Vector2.init(@floatFromInt(snapX), @floatFromInt(snapY));
        }

        fn toIndex(x: i32, y: i32) ?usize {
            if (0 > x or x >= cols) { return null; }
            if (0 > y or y >= rows) { return null; }
            const index: usize = @intCast(y * @as(i32, @intCast(cols)) + x);
            return index;
        }

        fn place(self: Grid(rows, cols), tile: Tile) Grid(rows, cols) {
            const c = self.coords(tile.pos);
            var grid = self;
            if (toIndex(c.x, c.y)) |index| {
                if (grid.tiles[index] == null) {
                    grid.tiles[index] = tile;
                }
            }
            return grid;
        }

        // need to use coords of tile not mouse because tile is animated and lags behind mouse
        fn canPlace(self: Grid(rows, cols), pos: rl.Vector2) bool {
            const c = self.coords(pos);
            if (toIndex(c.x, c.y)) |index| {
                if (self.tiles[index] == null) {
                    return true;
                }
            }
            return false;
        }

        fn update(self: Grid(rows, cols)) Grid(rows, cols) {
            var grid = self;
            for (0..rows) |row| {
                for (0..cols) |col| {
                    const r: i32 = @intCast(col);
                    const c: i32 = @intCast(row);
                    const index = toIndex(r, c).?;
                    if (grid.tiles[index]) |tile| {
                        const target = rl.Vector2.init(
                            @floatFromInt(grid.posX + grid.tile_width * r),
                            @floatFromInt(grid.posY + grid.tile_height * c),
                        );
                        grid.tiles[index] = tile.settleInPlace(target);
                    }
                }
            }
            return grid;
        }
    };
}

const Tile = struct {
    pos: rl.Vector2,
    width: i32,
    height: i32,
    hover: f32,
    thick: i32,
    letter: u8,

    fn posX(self: Tile) i32 {
        return @intFromFloat(self.pos.x);
    }

    fn posY(self: Tile) i32 {
        return @intFromFloat(self.pos.y);
    }

    fn draw(self: Tile, face: rl.Color, edge: rl.Color, letter: rl.Color) void {
        const hover: i32 = @intFromFloat(self.hover);
        const text = [1:0]u8{self.letter};
        rl.drawRectangle(self.posX(), self.posY() - self.thick - hover + self.height, self.width, self.thick, edge);
        rl.drawRectangle(self.posX(), self.posY() - self.thick - hover, self.width, self.height, face);
        rl.drawText((&text).ptr, self.posX() + 7, self.posY() - self.thick - hover + 4, 20, letter);
    }

    fn followMouse(self: Tile, mouse: rl.Vector2, snap: rl.Vector2) Tile {
        const pos_mouse = rl.math.vector2Lerp(self.pos, mouse, 0.1);
        const pos_snap = rl.math.vector2Lerp(pos_mouse, snap, 0.2);
        var tile = self;
        tile.pos = pos_snap;
        return tile;
    }

    fn settleInPlace(self: Tile, target: rl.Vector2) Tile {
        const pos_new = rl.math.vector2Lerp(self.pos, target, 0.3);
        var tile = self;
        tile.pos = pos_new;
        tile.hover = rl.math.lerp(tile.hover, 0.0, 0.08);
        return tile;
    }
};


pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "game game");
    defer rl.closeWindow();
    rl.setTargetFPS(120);

    const Grid15 = Grid(15, 15);
    var grid = Grid15 {
        .posX = 175,
        .posY = 75,
        .tile_width = 30,
        .tile_height = 30,
        .gap = 2,
        .tiles = [_]?Tile{null} ** (15 * 15),
    };

    var tile = Tile {
        .pos = rl.Vector2.init(0.0, 0.0),
        .width = grid.width(),
        .height = grid.height(),
        .hover = 0,
        .thick = 4,
        .letter = 65,
    };

    const table_image = rl.loadImageFromMemory(".jpg", table_image_data);
    const table_texture = rl.loadTextureFromImage(table_image);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);
        rl.drawTexture(table_texture, 0, 0, rl.Color.white);
        defer rl.drawFPS(10, 10);

        const t = rl.getTime();
        rl.drawText("math scrabble game thing", 175, 30, 20, rl.Color.dark_brown.alpha(0.2));

        grid = grid.update();
        grid.draw(rl.Color.dark_brown.alpha(0.2));

        const mouse = rl.getMousePosition();
        const snap = grid.snap(mouse);
        tile.hover = @floatCast(@sin(t * 4.0) * 2.0 + 4.0);
        tile = tile.followMouse(mouse, snap);

        if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
            grid = grid.place(tile);
            tile.letter += 1;
            if (tile.letter > 65 + 25) {
                tile.letter = 65;
            }
        }

        if (grid.canPlace(tile.pos)) {
            tile.draw(rl.Color.purple, rl.Color.dark_purple, rl.Color.white);
        } else {
            const face = rl.Color.white.alpha(0.7);
            const edge = rl.Color.light_gray.alpha(0.7);
            const letter = rl.Color.black.alpha(0.3);
            tile.draw(face, edge, letter);
        }
    }
}
