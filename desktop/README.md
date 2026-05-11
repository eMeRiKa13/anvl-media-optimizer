# ANVL Desktop

Zero Native shell for running ANVL as a local macOS desktop app.

## Setup

Requirements:

- Zig 0.16+
- Global `zero-native` CLI
- Node.js available from the user's shell

The generated build defaults to this Zero Native framework path:

```text
/Users/emerika/.nvm/versions/node/v22.22.2/lib/node_modules/zero-native

```

Override it with `-Dzero-native-path=/path/to/zero-native` if you move this app.

## Commands

```sh
npm run dev:mac
npm run mac:launcher
zero-native doctor --manifest desktop/app.zon
```

From this directory, lower-level Zero Native commands are also available:

```sh
zig build test
zig build package
zero-native doctor --manifest app.zon
```

ANVL's normal local flow is owned by the root `npm run dev:mac` script. It starts
or reuses the Express server on `127.0.0.1:4000`, starts or reuses Nuxt on
`127.0.0.1:4350`, then launches this Zero Native shell with
`ZERO_NATIVE_FRONTEND_URL`.

The local Dock launcher is generated at `dist/ANVL.app` by
`npm run mac:launcher`. It uses `assets/logo.icns` as the app icon and creates a
small native launcher binary that logs to
`~/Library/Logs/dev.anvl.local/launcher.log`.

The app window intentionally does not restore previous window state. It opens at
a fixed default size so it does not disappear off-screen after monitor changes.

## Web Engines

The generated app defaults to the system WebView. On macOS you can switch to Chromium/CEF with:

```sh
zero-native cef install
zig build run -Dplatform=macos -Dweb-engine=chromium
```

`zero-native cef install` downloads zero-native's prepared CEF runtime, including the native wrapper library.

For one-command local setup, opt into build-time install:

```sh
zig build run -Dplatform=macos -Dweb-engine=chromium -Dcef-auto-install=true
```

Use `-Dcef-dir=/path/to/cef` when you keep CEF outside the platform default under `third_party/cef`.

```sh
zero-native doctor --web-engine chromium
```

Diagnostics:

- Set `ZERO_NATIVE_LOG_DIR` to override the platform log directory during development.
- Set `ZERO_NATIVE_LOG_FORMAT=text|jsonl` to choose persistent log format.
