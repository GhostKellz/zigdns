pub const packages = struct {
    pub const @"zcrypto-0.5.0-rgQAIw0vBwBwYxfz-NNHyJbWzJqnacg9PDrEOcBiwf7D" = struct {
        pub const build_root = "/home/chris/.cache/zig/p/zcrypto-0.5.0-rgQAIw0vBwBwYxfz-NNHyJbWzJqnacg9PDrEOcBiwf7D";
        pub const build_zig = @import("zcrypto-0.5.0-rgQAIw0vBwBwYxfz-NNHyJbWzJqnacg9PDrEOcBiwf7D");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"zquic-0.3.0-2rPds13HkxPqjeJMiwXVesuWsJyQFrQ7hnHCJaKNiCco" = struct {
        pub const build_root = "/home/chris/.cache/zig/p/zquic-0.3.0-2rPds13HkxPqjeJMiwXVesuWsJyQFrQ7hnHCJaKNiCco";
        pub const build_zig = @import("zquic-0.3.0-2rPds13HkxPqjeJMiwXVesuWsJyQFrQ7hnHCJaKNiCco");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "zcrypto", "zcrypto-0.5.0-rgQAIw0vBwBwYxfz-NNHyJbWzJqnacg9PDrEOcBiwf7D" },
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "zquic", "zquic-0.3.0-2rPds13HkxPqjeJMiwXVesuWsJyQFrQ7hnHCJaKNiCco" },
};
