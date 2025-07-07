pub const packages = struct {
    pub const @"zcrypto-0.5.0-rgQAI8ouBwCClV_t59bD7KJ13ZMoI3gjbv4a0E1uLr9o" = struct {
        pub const build_root = "/home/chris/.cache/zig/p/zcrypto-0.5.0-rgQAI8ouBwCClV_t59bD7KJ13ZMoI3gjbv4a0E1uLr9o";
        pub const build_zig = @import("zcrypto-0.5.0-rgQAI8ouBwCClV_t59bD7KJ13ZMoI3gjbv4a0E1uLr9o");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"zquic-0.4.0-2rPds3IBlBMVAfAvDBWynr3pV_zsxqUcaIxIfmZiMCnU" = struct {
        pub const build_root = "/home/chris/.cache/zig/p/zquic-0.4.0-2rPds3IBlBMVAfAvDBWynr3pV_zsxqUcaIxIfmZiMCnU";
        pub const build_zig = @import("zquic-0.4.0-2rPds3IBlBMVAfAvDBWynr3pV_zsxqUcaIxIfmZiMCnU");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "zcrypto", "zcrypto-0.5.0-rgQAI8ouBwCClV_t59bD7KJ13ZMoI3gjbv4a0E1uLr9o" },
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "zquic", "zquic-0.4.0-2rPds3IBlBMVAfAvDBWynr3pV_zsxqUcaIxIfmZiMCnU" },
    .{ "zcrypto", "zcrypto-0.5.0-rgQAI8ouBwCClV_t59bD7KJ13ZMoI3gjbv4a0E1uLr9o" },
};
