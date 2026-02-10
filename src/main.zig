const std = @import("std");
const mine_Sweeper_zig = @import("mine_Sweeper_zig");
const GB = @import("gameboard.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var gb = try GB.GameBoard.init(allocator, 9, 9, 10);
    defer gb.deinit();

    try gb.cuiGames();
}
