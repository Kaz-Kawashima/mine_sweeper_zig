const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Panel = @import("Panel.zig");
const PanelUnion = Panel.PanelUnion;
const BlankPanel = Panel.BlankPanel;
const BombPanel = Panel.BombPanel;
const BorderPanel = Panel.BorderPanel;
const GK = @import("GetKey.zig");
const GetKey = GK.GetKey;
const KeyInput = GK.KeyInput;
const GameStatus = enum { Uninitialized, Playing, Win, Lose };
const Uninitialized = GameStatus.Uninitialized;
const Playing = GameStatus.Playing;
const Win = GameStatus.Win;
const Lose = GameStatus.Lose;

pub const GameBoard = struct {
    allocator: Allocator,
    field: ArrayList(ArrayList(PanelUnion)),
    print_buffer: ArrayList(u8),
    size_x: usize,
    size_y: usize,
    field_size_x: usize,
    field_size_y: usize,
    cursor_row: usize,
    cursor_col: usize,
    num_bomb: usize,
    flag_count: usize,
    status: GameStatus,
    stdout_buffer: [1024]u8,

    pub fn init(allocator: Allocator, y: usize, x: usize, num_bomb: usize) !GameBoard {
        // const panel_row = ArrayList(Panel).init(allocator);
        var field_ = ArrayList(ArrayList(PanelUnion)){};
        errdefer {
            for (field_.items) |*panel_row| {
                panel_row.deinit(allocator);
            }
            field_.deinit(allocator);
        }
        var print_buffer_ = ArrayList(u8){};
        defer print_buffer_.deinit(allocator);

        var gb = GameBoard{ .field = field_, .print_buffer = print_buffer_, .allocator = allocator, .size_y = y, .size_x = x, .field_size_y = (y + 2), .field_size_x = (x + 2), .cursor_col = 1, .cursor_row = 1, .num_bomb = num_bomb, .flag_count = 0, .status = Uninitialized, .stdout_buffer = undefined };
        try gb.fillGameBoard();
        // gb.initStdoutBuffer();
        return gb;
    }

    pub fn deinit(self: *GameBoard) void {
        for (self.field.items) |*panel_row| {
            panel_row.deinit(self.allocator);
        }
        self.field.deinit(self.allocator);
        self.print_buffer.deinit(self.allocator);
    }

    fn fillGameBoard(self: *GameBoard) !void {
        for (0..self.field_size_y) |row| {
            // var panel_row = self.field.items[row];
            var panel_row = ArrayList(PanelUnion){};
            if (row == 0 or row == (self.field_size_y - 1)) {
                for (0..self.field_size_x) |_| {
                    const p = PanelUnion{ .BorderPanel = BorderPanel.init() };
                    try panel_row.append(self.allocator, p);
                }
            } else {
                for (0..self.field_size_x) |col| {
                    if (col == 0 or col == (self.field_size_x - 1)) {
                        try panel_row.append(self.allocator, PanelUnion{ .BorderPanel = BorderPanel.init() });
                    } else {
                        try panel_row.append(self.allocator, PanelUnion{ .BlankPanel = BlankPanel.init(null) });
                    }
                }
            }
            try self.field.append(self.allocator, panel_row);
        }
    }

    pub fn setBomb(self: *GameBoard) !void {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        var prng = std.Random.DefaultPrng.init(seed);
        var num_bomb: usize = 0;

        while (num_bomb < self.num_bomb) {
            const random = prng.random();
            const y = random.uintLessThan(usize, self.size_y + 1);
            const x = random.uintLessThan(usize, self.size_x + 1);
            if ((y == self.cursor_row) and (x == self.cursor_col)) {
                continue;
            }
            const panel = &self.field.items[y].items[x];
            const f = panel.isFlagged();
            switch (panel.*) {
                .BlankPanel => {
                    num_bomb += 1;
                    self.field.items[y].items[x] = PanelUnion{ .BombPanel = BombPanel.init(f) };
                    self.incrementBombValue(y, x);
                },
                else => {},
            }
        }
        self.status = Playing;
    }

    fn incrementBombValue(self: *GameBoard, row: usize, col: usize) void {
        for ((row - 1)..(row + 2)) |y| {
            for ((col - 1)..(col + 2)) |x| {
                const panel = &self.field.items[y].items[x];
                switch (panel.*) {
                    .BlankPanel => |*p| {
                        p.bomb_value += 1;
                    },
                    else => {},
                }
            }
        }
    }

    pub fn print(self: *GameBoard) !void {
        self.print_buffer.clearRetainingCapacity();
        var p_char: u8 = ' ';
        for (0..self.field_size_y) |row| {
            for (0..self.field_size_x) |col| {
                if ((row == self.cursor_row) and (col == self.cursor_col)) {
                    p_char = '@';
                } else if ((row == self.cursor_row) and (col == 0)) {
                    p_char = '>';
                } else if ((row == self.cursor_row) and (col == self.size_x + 1)) {
                    p_char = '<';
                } else if ((row == 0) and (col == self.cursor_col)) {
                    p_char = 'v';
                } else if ((row == self.size_y + 1) and (col == self.cursor_col)) {
                    p_char = '^';
                } else {
                    p_char = self.field.items[row].items[col].toChar();
                }
                try self.print_buffer.append(self.allocator, p_char);
                try self.print_buffer.append(self.allocator, ' ');
            }
            try self.print_buffer.append(self.allocator, '\n');
        }

        const gb_string = self.print_buffer.items;
        var stdout_writer = std.fs.File.stdout().writer(&self.stdout_buffer);
        const stdout = &stdout_writer.interface;
        //clear screen
        try stdout.print("\x1B[2J\x1B[H", .{});
        try stdout.flush();
        //print game board
        try stdout.print("{s}\ninput <- ^v -> / O open / F flag ({d})\n{s}", .{ gb_string, self.flag_count, self.gameStatusMessage() });
        try stdout.flush();
    }

    fn gameStatusMessage(self: *GameBoard) []const u8 {
        switch (self.status) {
            .Win => {
                return "You Win!";
            },
            .Lose => {
                return "Game Over!";
            },
            else => {
                return "";
            },
        }
    }

    fn countFlag(self: *GameBoard) void {
        var count: usize = 0;
        for (self.field.items) |panel_row| {
            for (panel_row.items) |p| {
                if (p.isFlagged()) {
                    count += 1;
                }
            }
        }
        self.flag_count = count;
    }

    //debug_print
    pub fn debug_print(self: *GameBoard) !void {
        self.print_buffer.clearRetainingCapacity();
        var p_char: u8 = ' ';
        for (0..self.field_size_y) |row| {
            for (0..self.field_size_x) |col| {
                const p = &self.field.items[row].items[col];
                if ((row == self.cursor_row) and (col == self.cursor_col)) {
                    p_char = '@';
                } else if ((row == self.cursor_row) and (col == 0)) {
                    p_char = '>';
                } else if ((row == self.cursor_row) and (col == self.size_x + 1)) {
                    p_char = '<';
                } else if ((row == 0) and (col == self.cursor_col)) {
                    p_char = 'v';
                } else if ((row == self.size_y + 1) and (col == self.cursor_col)) {
                    p_char = '^';
                } else {
                    p_char = p.toChar();
                }
                try self.print_buffer.append(self.allocator, p_char);
                try self.print_buffer.append(self.allocator, p.toCharDebug());
            }
            try self.print_buffer.append(self.allocator, '\n');
        }

        const gb_string = self.print_buffer.items;

        var stdout_writer = std.fs.File.stdout().writer(&self.stdout_buffer);
        const stdout = &stdout_writer.interface;
        try stdout.print("{s}", .{gb_string});
        try stdout.flush();
    }

    fn up(self: *GameBoard) void {
        self.cursor_row -= 1;
        if (self.cursor_row < 1) {
            self.cursor_row = 1;
        }
    }
    fn down(self: *GameBoard) void {
        self.cursor_row += 1;
        if (self.cursor_row > self.size_y) {
            self.cursor_row = self.size_y;
        }
    }
    fn left(self: *GameBoard) void {
        self.cursor_col -= 1;
        if (self.cursor_col < 1) {
            self.cursor_col = 1;
        }
    }
    fn right(self: *GameBoard) void {
        self.cursor_col += 1;
        if (self.cursor_col > self.size_x) {
            self.cursor_col = self.size_x;
        }
    }
    fn flag(self: *GameBoard) void {
        const row = self.cursor_row;
        const col = self.cursor_col;
        var panel = &self.field.items[row].items[col];
        panel.flag();
    }

    fn openPos(self: *GameBoard, row: usize, col: usize) bool {
        var panel = &self.field.items[row].items[col];
        if (panel.isOpen() or panel.isFlagged()) {
            return true;
        }
        const is_safe = panel.open();
        if (is_safe) {
            switch (panel.*) {
                .BlankPanel => |bp| {
                    if (bp.bomb_value == 0) {
                        _ = self.openPos(row - 1, col - 1);
                        _ = self.openPos(row - 1, col);
                        _ = self.openPos(row - 1, col + 1);
                        _ = self.openPos(row, col - 1);
                        _ = self.openPos(row, col + 1);
                        _ = self.openPos(row + 1, col - 1);
                        _ = self.openPos(row + 1, col);
                        _ = self.openPos(row + 1, col + 1);
                    }
                },
                .BorderPanel => {},
                .BombPanel => {
                    std.debug.assert(false);
                    // std.debug.print("AAAAA!!!", .{});
                },
            }
        }
        return is_safe;
    }

    fn open(self: *GameBoard) !bool {
        if (self.status == Uninitialized) {
            try self.setBomb();
        }
        return self.openPos(self.cursor_row, self.cursor_col);
    }

    fn bombOpen(self: *GameBoard) void {
        for (self.field.items) |panel_row| {
            for (panel_row.items) |*panel| {
                switch (panel.*) {
                    .BombPanel => |*p| {
                        _ = p.open();
                    },
                    else => {},
                }
            }
        }
    }

    fn updateStatus(self: *GameBoard) void {
        self.status = Win;
        for (self.field.items) |panel_row| {
            for (panel_row.items) |*panel| {
                switch (panel.*) {
                    .BlankPanel => |*p| {
                        if (!p.isOpen()) {
                            self.status = Playing;
                        }
                    },
                    .BombPanel => |*p| {
                        if (p.isOpen()) {
                            self.status = Lose;
                            return;
                        }
                    },
                    else => {},
                }
            }
        }
    }

    pub fn cuiGames(self: *GameBoard) !void {
        while ((self.status == Playing) or (self.status == Uninitialized)) {
            try self.print();
            const input = try GetKey();
            switch (input) {
                KeyInput.Up => {
                    self.up();
                },
                KeyInput.Down => {
                    self.down();
                },
                KeyInput.Left => {
                    self.left();
                },
                KeyInput.Right => {
                    self.right();
                },
                KeyInput.Open => {
                    _ = try self.open();
                    self.updateStatus();
                },
                KeyInput.Flag => {
                    self.flag();
                    self.countFlag();
                },
                KeyInput.Quit => {
                    self.status = Lose;
                },
            }
        }
        if (self.status == Lose) {
            self.bombOpen();
        }
        try self.print();
    }
};
