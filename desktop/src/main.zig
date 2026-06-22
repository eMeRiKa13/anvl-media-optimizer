const std = @import("std");
const runner = @import("runner");
const zero_native = @import("zero-native");

pub const panic = std.debug.FullPanic(zero_native.debug.capturePanic);

const App = struct {
    env_map: *std.process.Environ.Map,

    fn app(self: *@This()) zero_native.App {
        return .{
            .context = self,
            .name ="anvl",
            .source = zero_native.frontend.productionSource(.{ .dist ="frontend/dist" }),
            .source_fn = source,
        };
    }

    fn source(context: *anyopaque) anyerror!zero_native.WebViewSource {
        const self: *@This() = @ptrCast(@alignCast(context));
        return zero_native.frontend.sourceFromEnv(self.env_map, .{
            .dist ="frontend/dist",
            .entry = "index.html",
        });
    }
};

const dev_origins = [_][]const u8{ "zero://app", "zero://inline", "http://127.0.0.1:4350", "http://127.0.0.1:4000" };
const native_file_permissions = [_][]const u8{ "filesystem" };
const dialog_bridge_commands = [_]zero_native.BridgeCommandPolicy{
    .{
        .name = "zero-native.dialog.openFile",
        .permissions = &native_file_permissions,
        .origins = &dev_origins,
    },
};

pub fn main(init: std.process.Init) !void {
    var app = App{ .env_map = init.environ_map };
    try runner.runWithOptions(app.app(), .{
        .app_name ="ANVL",
        .window_title ="ANVL",
        .bundle_id ="dev.anvl.local",
        .icon_path = "assets/logo.icns",
        .builtin_bridge = .{
            .enabled = true,
            .permissions = &native_file_permissions,
            .commands = &dialog_bridge_commands,
        },
        .security = .{
            .permissions = &native_file_permissions,
            .navigation = .{ .allowed_origins = &dev_origins },
        },
    }, init);
}

test "app name is configured" {
    try std.testing.expectEqualStrings("anvl","anvl");
}
