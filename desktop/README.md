# ANVL Desktop

Zero Native shell for running ANVL as a local macOS desktop app.

## Requirements

To build `dist/ANVL.app`:

- macOS
- Node.js available from the shell
- Project dependencies installed with `npm install`
- Zig 0.16+
- clang
- `ditto`
- Global `zero-native` CLI or `ZERO_NATIVE_PATH=/path/to/zero-native`

To run the generated app:

- macOS on the same CPU architecture as the build machine
- No local repository checkout, npm, Zig, or `zero-native` install is required

The generated app is unsigned and not notarized.

## Commands

From the repository root:

```sh
npm run dev:mac
npm run mac:launcher
```

`npm run dev:mac` is the development flow. It starts or reuses the Express server
on `127.0.0.1:4000`, starts or reuses Nuxt on `127.0.0.1:4350`, waits for HTTP
readiness, then launches the Zero Native shell with `ZERO_NATIVE_FRONTEND_URL`.

`npm run mac:launcher` creates `dist/ANVL.app`. The script resolves the Zero
Native framework dynamically from:

- `ZERO_NATIVE_PATH`, when provided
- `npm root -g` plus `/zero-native`
- the installed `zero-native` binary path

From this directory, lower-level Zero Native commands are also available:

```sh
zig build test
zig build package
zero-native doctor --manifest app.zon
```

## Generated App

`dist/ANVL.app` contains:

- the compiled `ANVLNative` Zero Native shell
- `Contents/Resources/run-anvl-mac.sh`
- a bundled Node executable
- the client, server, root `node_modules`, and workspace `node_modules`
- `assets/logo.icns` as the app icon

At launch, the wrapper computes paths from its own `.app` location. It does not
embed the repository path, so the app can be moved or copied after build.

The launcher copies the bundled web runtime into:

```text
~/Library/Application Support/ANVL/runtime.*
```

The server and Nuxt client run from that temporary runtime directory instead of
from `Documents`, `Desktop`, or the repository. This avoids macOS protected-folder
launch issues when the app is opened from Finder or the Dock.

When the app exits, the launcher stops the local server/client processes and
removes the temporary runtime directory.

## Runtime Behavior

Default local ports:

- Client: `http://127.0.0.1:4350`
- Nuxt HMR: `127.0.0.1:4351`
- Server: `http://127.0.0.1:4000`

Environment overrides:

```sh
ANVL_CLIENT_PORT=4352 ANVL_HMR_PORT=4353 ANVL_SERVER_PORT=4001 npm run dev:mac
```

Native file upload and download are protected by a per-launch token. The launcher
passes the same token to the Express server and Nuxt client. If an old server or
client is already running with a different token, the launcher stops it and starts
a fresh one.

Native downloads are written to `~/Downloads`. Name collisions are handled with a
numeric suffix.

## Logs

Launcher logs:

```text
~/Library/Logs/dev.anvl.local/launcher.log
```

Zero Native logs:

```text
~/Library/Logs/dev.anvl.local/zero-native.jsonl
```

During development:

- Set `ZERO_NATIVE_LOG_DIR` to override the platform log directory.
- Set `ZERO_NATIVE_LOG_FORMAT=text|jsonl` to choose the persistent log format.

## Updating The App

Rebuild the launcher after changing:

- client source
- server source
- desktop source
- dependencies
- `script/run-anvl-mac.sh`
- app icon assets

```sh
npm run mac:launcher
```

`dist/ANVL.app` is ignored by git and can be recreated at any time.

## Troubleshooting

### App opens then immediately closes

Check:

```sh
tail -n 120 ~/Library/Logs/dev.anvl.local/launcher.log
tail -n 120 ~/Library/Logs/dev.anvl.local/zero-native.jsonl
```

Common causes:

- The app was built before the latest launcher changes. Rebuild with `npm run mac:launcher`.
- Port `4000`, `4350`, or `4351` is already used by another process.
- The native upload/download token is stale because an old ANVL server/client is still running.

### Upload or download works in browser but not in the app

Rebuild and relaunch the `.app`:

```sh
npm run mac:launcher
open dist/ANVL.app
```

The macOS app uses a native bridge for file selection and protected local
endpoints for file reads/downloads. Browser upload and download continue to use
standard web APIs.

### App copied to another Mac does not open

The generated app is architecture-specific and unsigned. Build on a compatible
Mac, or produce separate builds for Apple silicon and Intel. Because the app is
not notarized, macOS may require opening it from Finder with the normal unsigned
app approval flow.

## Web Engines

The generated app defaults to the system WebView. On macOS you can switch to
Chromium/CEF with:

```sh
zero-native cef install
zig build run -Dplatform=macos -Dweb-engine=chromium
```

`zero-native cef install` downloads Zero Native's prepared CEF runtime, including
the native wrapper library.

For one-command local setup, opt into build-time install:

```sh
zig build run -Dplatform=macos -Dweb-engine=chromium -Dcef-auto-install=true
```

Use `-Dcef-dir=/path/to/cef` when you keep CEF outside the platform default under
`third_party/cef`.

```sh
zero-native doctor --web-engine chromium
```
