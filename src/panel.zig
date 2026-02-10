pub const PanelType = enum { BlankPanel, BombPanel, BorderPanel };
pub const PanelUnion = union(PanelType) {
    BlankPanel: BlankPanel,
    BombPanel: BombPanel,
    BorderPanel: BorderPanel,

    pub fn flag(self: *PanelUnion) void {
        switch (self.*) {
            .BorderPanel => {},
            .BlankPanel => |*p| {
                p.flag();
            },
            .BombPanel => |*p| {
                p.flag();
            },
        }
    }

    pub fn open(self: *PanelUnion) bool {
        switch (self.*) {
            .BorderPanel => {
                return true;
            },
            .BlankPanel => |*p| {
                return p.open();
            },
            .BombPanel => |*p| {
                return p.open();
            },
        }
    }

    pub fn isFlagged(self: *const PanelUnion) bool {
        switch (self.*) {
            inline else => |*p| {
                return p.base.is_flagged;
            },
        }
    }
    pub fn isOpen(self: *const PanelUnion) bool {
        switch (self.*) {
            inline else => |*p| {
                return p.isOpen();
            },
        }
    }

    pub fn toChar(self: *const PanelUnion) u8 {
        switch (self.*) {
            inline else => |*p| {
                return p.toChar();
            },
        }
    }

    pub fn toCharDebug(self: *const PanelUnion) u8 {
        switch (self.*) {
            .BlankPanel => |*p| {
                return '0' + p.bomb_value;
            },
            .BombPanel => {
                return 'B';
            },
            .BorderPanel => {
                return '-';
            },
        }
    }
};

const PanelBase = struct {
    is_open: bool,
    is_flagged: bool,

    pub fn init(f: ?bool) PanelBase {
        return PanelBase{
            .is_open = false,
            .is_flagged = f orelse false,
        };
    }
    pub fn flag(self: *PanelBase) void {
        self.is_flagged = !self.is_flagged;
    }
    pub fn open(self: *PanelBase) void {
        if (!self.is_flagged) {
            self.is_open = true;
        }
    }
};

pub const BlankPanel = struct {
    base: PanelBase,
    bomb_value: u8,
    pub fn init(f: ?bool) BlankPanel {
        return BlankPanel{ .base = PanelBase.init(f), .bomb_value = 0 };
    }
    pub fn open(self: *BlankPanel) bool {
        self.base.open();
        return true;
    }
    pub fn flag(self: *BlankPanel) void {
        self.base.flag();
    }
    pub fn isOpen(self: *const BlankPanel) bool {
        return self.base.is_open;
    }

    pub fn toChar(self: *const BlankPanel) u8 {
        if (self.base.is_flagged) {
            return 'F';
        } else if (self.base.is_open) {
            if (self.bomb_value == 0) {
                return ' ';
            } else {
                return (self.bomb_value + '0');
            }
        } else {
            return '#';
        }
    }
};

pub const BombPanel = struct {
    base: PanelBase,
    pub fn init(f: ?bool) BombPanel {
        return BombPanel{ .base = PanelBase.init(f) };
    }
    pub fn flag(self: *BombPanel) void {
        self.base.flag();
    }
    pub fn isOpen(self: *const BombPanel) bool {
        return self.base.is_open;
    }

    pub fn open(self: *BombPanel) bool {
        if (self.base.is_flagged) {
            return true;
        } else {
            self.base.is_open = true;
            return false;
        }
    }

    pub fn toChar(self: *const BombPanel) u8 {
        if (self.base.is_flagged) {
            return 'F';
        } else if (self.base.is_open) {
            return 'B';
        } else {
            return '#';
        }
    }
};

pub const BorderPanel = struct {
    base: PanelBase,
    pub fn init() BorderPanel {
        return BorderPanel{ .base = PanelBase.init(null) };
    }
    pub fn isOpen(self: *const BorderPanel) bool {
        return self.base.is_open;
    }
    pub fn toChar(_: *const BorderPanel) u8 {
        return '=';
    }
};
