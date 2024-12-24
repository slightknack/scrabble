const std = @import("std");
const rl = @import("raylib");

const image_table = @embedFile("./assets/table-light.jpg");
const sound_place = @embedFile("./assets/place.wav");
const sound_pickup = @embedFile("./assets/pickup.wav");
const sound_tap = @embedFile("./assets/tap.wav");

fn Grid(comptime num_rows: usize, comptime num_cols: usize) type {
    return struct {
        const Self = @This();
        rows: usize = num_rows,
        cols: usize = num_cols,
        posX: i32,
        posY: i32,
        tile_width: i32,
        tile_height: i32,
        gap: i32,
        // like some text in a book, left to right, top to bottom
        tiles: [num_rows * num_cols]?Tile,

        fn width(self: Self) i32 {
            return self.tile_width - self.gap;
        }

        fn height(self: Self) i32 {
            return self.tile_height - self.gap;
        }

        /// draw the grid background and all the tiles on the grid
        fn draw(
            self: Self,
            color: rl.Color,
        ) void {
            // draw the grid background
            for (0..self.rows) |row| {
                for (0..self.cols) |col| {
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

        /// given a position in screen space, return the row and column of the position. may be out of bounds.
        fn coords(self: Self, pos: rl.Vector2) struct { x: i32, y: i32 } {
            const posX: i32 = @intFromFloat(pos.x);
            const posY: i32 = @intFromFloat(pos.y);
            const snapX: i32 = @divFloor((posX - self.posX), self.tile_width);
            const snapY: i32 = @divFloor((posY - self.posY), self.tile_height);
            return .{ .x = snapX, .y = snapY };
        }

        /// given a position in screen space, return the top-left corner of the corresponding grid tile in screen space
        fn snap(self: Self, pos: rl.Vector2) rl.Vector2 {
            const coord = self.coords(pos);
            const snapX: i32 = coord.x * self.tile_width + self.posX;
            const snapY: i32 = coord.y * self.tile_height + self.posY;
            return rl.Vector2.init(@floatFromInt(snapX), @floatFromInt(snapY));
        }

        /// given a row and a column, find the index of the tile in the tile list
        fn toIndex(self: Self, x: i32, y: i32) ?usize {
            if (0 > x or x >= self.cols) {
                return null;
            }
            if (0 > y or y >= self.rows) {
                return null;
            }
            const index: usize = @intCast(y * @as(i32, @intCast(self.cols)) + x);
            return index;
        }

        /// returns whether the tile was placed
        fn place(self: *Self, tile: Tile) bool {
            const c = self.coords(tile.pos);
            if (self.toIndex(c.x, c.y)) |index| {
                if (self.tiles[index] == null) {
                    self.tiles[index] = tile;
                    return true;
                }
            }
            return false;
        }

        /// you need to use coords of tile not mouse because tile is animated and lags behind mouse
        fn canPlace(self: Self, pos: rl.Vector2) bool {
            const c = self.coords(pos);
            if (self.toIndex(c.x, c.y)) |index| {
                if (self.tiles[index] == null) {
                    return true;
                }
            }
            return false;
        }

        fn pickUp(self: *Self, pos: rl.Vector2) ?Tile {
            const c = self.coords(pos);
            if (self.toIndex(c.x, c.y)) |index| {
                if (self.tiles[index]) |tile| {
                    self.tiles[index] = null;
                    return tile;
                }
            }
            return null;
        }

        /// given a row and a column, returns the top-left corner in screen space
        fn toTarget(self: Self, x: i32, y: i32) rl.Vector2 {
            return rl.Vector2.init(
                @floatFromInt(self.posX + self.tile_width * x),
                @floatFromInt(self.posY + self.tile_height * y),
            );
        }

        /// animate placed tiles towards their resting grid positions. should be called once per frame.
        fn update(self: *Self) void {
            for (0..self.rows) |row| {
                for (0..self.cols) |col| {
                    const r: i32 = @intCast(col);
                    const c: i32 = @intCast(row);
                    // guaranteed to be within bounds
                    const index = self.toIndex(r, c).?;
                    const target = self.toTarget(r, c);
                    var tile = &(self.tiles[index] orelse continue);
                    tile.settleInPlace(target);
                }
            }
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

    /// draw the tile with the given colors
    fn draw(self: Tile, face: rl.Color, edge: rl.Color, letter: rl.Color) void {
        const hover: i32 = @intFromFloat(self.hover);
        const text = [1:0]u8{self.letter};
        rl.drawRectangle(self.posX(), self.posY() - self.thick - hover + self.height, self.width, self.thick, edge);
        rl.drawRectangle(self.posX(), self.posY() - self.thick - hover, self.width, self.height, face);
        rl.drawText((&text).ptr, self.posX() + 7, self.posY() - self.thick - hover + 4, 20, letter);
    }

    /// animate the tile towards the mouse, biased towards the grid. should be called once per frame.
    fn followMouse(self: *Tile, mouse: rl.Vector2, snap: rl.Vector2) void {
        const pos_mouse = rl.math.vector2Lerp(self.pos, mouse, 0.1);
        const pos_snap = rl.math.vector2Lerp(pos_mouse, snap, 0.2);
        self.pos = pos_snap;
    }

    /// animate the tile towards a given target. should be called once per frame
    fn settleInPlace(self: *Tile, target: rl.Vector2) void {
        self.pos = rl.math.vector2Lerp(self.pos, target, 0.3);
        self.hover = rl.math.lerp(self.hover, 0.0, 0.08);
    }
};

const Rack = struct {
    grid: GridRack,
    border: i32,
    thick: i32,

    /// draws the background rack, and the grid on the rack.
    fn draw(self: Rack, rack: rl.Color, spot: rl.Color) void {
        rl.drawRectangle(
            self.grid.posX - self.border,
            self.grid.posY - self.border,
            self.grid.tile_width * 7 + self.border * 2,
            self.grid.tile_height + self.border * 2,
            rack,
        );
        rl.drawRectangle(
            self.grid.posX - self.border,
            self.grid.posY + self.border + self.grid.tile_height,
            self.grid.tile_width * 7 + self.border * 2,
            self.thick,
            spot,
        );
        self.grid.draw(spot);
    }

    fn fill(self: *Rack, bag: *Bag) void {
        for (0..self.grid.cols) |col| {
            // guaranteed to be on the grid
            const index = self.grid.toIndex(@intCast(col), 0).?;
            if (self.grid.tiles[index] == null) {
                self.grid.tiles[index] = Tile{
                    .pos = self.grid.toTarget(@intCast(col), 0),
                    .width = self.grid.width(),
                    .height = self.grid.height(),
                    .hover = 0.0,
                    .thick = 4,
                    .letter = bag.pick(),
                };
            }
        }
    }

    fn isEmpty(self: Rack) bool {
        var empty = true;
        for (self.grid.tiles) |tile| {
            if (tile) |_| {
                empty = false;
            }
        }
        return empty;
    }
};

const GridBoard = Grid(15, 15);
const GridRack = Grid(1, 7);

/// don't ask
const scrabble_bag: *const [98:0]u8 = "EEEEEEEEEEEEAAAAAAAAAIIIIIIIIIOOOOOOOONNNNNNRRRRRRTTTTTTLLLLSSSSUUUUDDDDGGGBBCCMMPPFFHHVVWWYYKXJQZ";

const Bag = struct {
    scrambled: [98]u8,
    next: usize,

    /// generate a fresh bag by shuffling the correct distribution of scrabble tiles
    fn fresh() Bag {
        const rand = std.crypto.random;
        var loc: [98]u8 = scrabble_bag.*;
        rand.shuffle(u8, &loc);
        return Bag{
            .scrambled = loc,
            .next = 0,
        };
    }

    /// pick a tile from the bag. if the bag is empty, replace with a fresh bag.
    fn pick(self: *Bag) u8 {
        const drawn = self.scrambled[self.next];
        self.next += 1;
        if (self.next >= self.scrambled.len) {
            self.* = Bag.fresh();
        }
        return drawn;
    }
};

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "game game");
    rl.initAudioDevice();
    rl.setTargetFPS(60);
    defer rl.closeWindow();
    defer rl.closeAudioDevice();

    var grid = GridBoard{
        .posX = 175,
        .posY = 45,
        .tile_width = 30,
        .tile_height = 30,
        .gap = 2,
        .tiles = [_]?Tile{null} ** (15 * 15),
    };

    var bag = Bag.fresh();
    const grid_rack = GridRack{
        .posX = 295,
        .posY = 525,
        .tile_width = 30,
        .tile_height = 30,
        .gap = 2,
        .tiles = [_]?Tile{null} ** (7),
    };
    var rack = Rack{
        .grid = grid_rack,
        .border = 8,
        .thick = 8,
    };
    rack.fill(&bag);

    var tile: Tile = Tile{
        .pos = rl.Vector2.init(0.0, 0.0),
        .width = grid.width(),
        .height = grid.height(),
        .hover = 0,
        .thick = 4,
        .letter = 65,
    };
    var tile_visible = false;

    const image_table_mem = rl.loadImageFromMemory(".jpg", image_table);
    const image_table_tex = rl.loadTextureFromImage(image_table_mem);

    const sound_pickup_mem = rl.loadWaveFromMemory(".wav", sound_pickup);
    const sound_place_mem = rl.loadWaveFromMemory(".wav", sound_place);
    const sound_tap_mem = rl.loadWaveFromMemory(".wav", sound_tap);
    const sound_pickup_wav = rl.loadSoundFromWave(sound_pickup_mem);
    const sound_place_wav = rl.loadSoundFromWave(sound_place_mem);
    const sound_tap_wav = rl.loadSoundFromWave(sound_tap_mem);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);
        rl.drawTexture(image_table_tex, 0, 0, rl.Color.white);
        defer rl.drawFPS(10, 10);

        const t = rl.getTime();
        rl.drawText("math scrabble game thing", 175, 10, 20, rl.Color.dark_brown.alpha(0.2));

        grid.update();
        rack.grid.update();
        grid.draw(rl.Color.dark_brown.alpha(0.2));
        rack.draw(rl.Color.sky_blue, rl.Color.blue);

        // TODO: don't snap if tile can't be placed
        var mouse = rl.getMousePosition();
        const snap = grid.snap(mouse);
        tile.hover = @floatCast(@sin(t * 4.0) * 2.0 + 4.0);
        if (grid.canPlace(mouse)) {
            tile.followMouse(mouse, snap);
        } else {
            mouse.y += 4.0;
            tile.settleInPlace(mouse);
        }

        if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
            if (tile_visible) {
                const placed_grid = grid.place(tile);
                const placed_rack = rack.grid.place(tile);
                const placed = placed_grid or placed_rack;
                if (placed) {
                    tile_visible = false;
                    rl.playSound(sound_tap_wav);
                }
                if (placed_grid and rack.isEmpty()) {
                    rack.fill(&bag);
                }
            } else {
                if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
                    if (grid.pickUp(mouse)) |got_tile| {
                        tile = got_tile;
                        tile_visible = true;
                        rl.playSound(sound_place_wav);
                    } else if (rack.grid.pickUp(mouse)) |got_tile| {
                        tile = got_tile;
                        tile_visible = true;
                        rl.playSound(sound_pickup_wav);
                    }
                }
            }
        }

        if (tile_visible) {
            if (grid.canPlace(tile.pos)) {
                tile.draw(rl.Color.purple, rl.Color.dark_purple, rl.Color.white);
            } else if (rack.grid.canPlace(tile.pos)) {
                tile.draw(rl.Color.orange, rl.Color.brown, rl.Color.white);
            } else {
                const face = rl.Color.white.alpha(0.7);
                const edge = rl.Color.light_gray.alpha(0.7);
                const letter = rl.Color.black.alpha(0.3);
                tile.draw(face, edge, letter);
            }
        }
    }
}
