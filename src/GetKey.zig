const std = @import("std");
const windows = std.os.windows;

pub const KeyInput = enum { Up, Down, Left, Right, Flag, Open, Quit };

// --- Windows API 構造体と定数の定義 ---
const INPUT_RECORD = extern struct {
    EventType: u16,
    Event: extern union {
        KeyEvent: KEY_EVENT_RECORD,
        MouseEvent: [16]u8,
        WindowBufferSizeEvent: [4]u8,
        MenuEvent: [4]u8,
        FocusEvent: [4]u8,
    },
};

const KEY_EVENT_RECORD = extern struct {
    bKeyDown: i32,
    wRepeatCount: u16,
    wVirtualKeyCode: u16,
    wVirtualScanCode: u16,
    uChar: extern union {
        UnicodeChar: u16,
        AsciiChar: u8,
    },
    dwControlKeyState: u32,
};

const KEY_EVENT: u16 = 0x0001;
const STD_INPUT_HANDLE: u32 = @bitCast(@as(i32, -10));

// --- Windows API 関数の手動宣言 (kernel32.dll) ---
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: u32) callconv(.winapi) i32;
extern "kernel32" fn SetConsoleCP(wCodePageID: u32) callconv(.winapi) i32;
extern "kernel32" fn ReadConsoleInputW(
    hConsoleInput: *anyopaque,
    lpBuffer: *INPUT_RECORD,
    nLength: u32,
    lpNumberOfEventsRead: *u32,
) callconv(.winapi) i32;

pub fn GetKey() !KeyInput {
    // 1. 日本語文字化け対策 (UTF-8)
    _ = SetConsoleOutputCP(65001);
    _ = SetConsoleCP(65001);

    const h = windows.kernel32.GetStdHandle(STD_INPUT_HANDLE).?;
    if (h == windows.INVALID_HANDLE_VALUE) return error.HandleInvalid;

    // 2. 現在のターミナル設定を保存
    var original_mode: u32 = undefined;
    if (windows.kernel32.GetConsoleMode(h, &original_mode) == 0) return error.GetConsoleModeFailed;

    // 3. 終了時に必ず元の設定（Ctrl+Cが効く状態など）に戻す
    defer {
        _ = windows.kernel32.SetConsoleMode(h, original_mode);
        // std.debug.print("\n設定を元に戻しました。終了します。\n", .{});
    }

    // 4. Rawモードに変更 (0x0000)
    // これにより、Enterを待たずに全てのキー入力をプログラムが直接受け取れるようになります
    _ = windows.kernel32.SetConsoleMode(h, 0x0000);

    // std.debug.print("--- Zig リアルタイム入力テスト ---\n", .{});
    // std.debug.print("矢印キーで操作 / Escキーでプログラムを終了します\n\n", .{});

    while (true) {
        var record: INPUT_RECORD = undefined;
        var read_count: u32 = 0;

        // キーイベントを取得するまで待機
        if (ReadConsoleInputW(h, &record, 1, &read_count) != 0) {
            // イベントの種類が「キーボード」かつ「キーが押し下げられた」時のみ処理
            if (record.EventType == KEY_EVENT and record.Event.KeyEvent.bKeyDown != 0) {
                const vk = record.Event.KeyEvent.wVirtualKeyCode;
                const char = record.Event.KeyEvent.uChar.UnicodeChar;

                switch (vk) {
                    0x1B => {
                        // Esc
                        return KeyInput.Quit;
                    },
                    0x26 => {
                        // ↑
                        return KeyInput.Up;
                    },
                    0x28 => {
                        // ↓
                        return KeyInput.Down;
                    },
                    0x25 => {
                        // ←
                        return KeyInput.Left;
                    },
                    0x27 => {
                        // →
                        return KeyInput.Right;
                    },
                    else => {
                        // 通常の文字入力の場合
                        if (char > 0) {
                            // UnicodeからASCIIに切り詰めて表示
                            const c = @as(u8, @truncate(char));
                            switch (c) {
                                'O', 'o' => {
                                    return KeyInput.Open;
                                },
                                'F', 'f' => {
                                    return KeyInput.Flag;
                                },
                                'Q', 'q' => {
                                    return KeyInput.Quit;
                                },
                                else => {},
                            }
                        }
                    },
                }
            }
        }
    }
}
