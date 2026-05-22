#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ANVL"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/$APP_NAME"
NATIVE_EXECUTABLE="$MACOS_DIR/${APP_NAME}Native"
LAUNCHER_SOURCE="$MACOS_DIR/${APP_NAME}.c"
CUSTOM_ICON="$ROOT_DIR/desktop/assets/logo.icns"
BUILD_VERSION="$(date +%Y%m%d%H%M%S)"
NODE_BIN_DIR="$(dirname "$(command -v node)")"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    echo "Install Zero Native prerequisites first: Zig 0.16+ and the zero-native CLI." >&2
    exit 1
  fi
}

resolve_zero_native_path() {
  local npm_root
  npm_root="$(npm root -g)"
  printf "%s/zero-native\n" "$npm_root"
}

require_command zig
require_command clang
require_command npm

ZERO_NATIVE_PATH="${ZERO_NATIVE_PATH:-$(resolve_zero_native_path)}"
if [[ ! -f "$ZERO_NATIVE_PATH/src/root.zig" ]]; then
  echo "Zero Native framework not found at: $ZERO_NATIVE_PATH" >&2
  echo "Install it with: npm install -g zero-native" >&2
  echo "Or set ZERO_NATIVE_PATH=/path/to/zero-native before running this script." >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

(
  cd "$ROOT_DIR/desktop"
  zig build -Dzero-native-path="$ZERO_NATIVE_PATH"
)
cp "$ROOT_DIR/desktop/zig-out/bin/$APP_NAME" "$NATIVE_EXECUTABLE"
chmod +x "$NATIVE_EXECUTABLE"

cat >"$LAUNCHER_SOURCE" <<EOF
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int main(void) {
  const char *root = "$ROOT_DIR";
  const char *home = getenv("HOME");
  if (home == NULL) {
    home = "/Users/emerika";
  }

  char log_dir[4096];
  char log_path[4096];
  snprintf(log_dir, sizeof(log_dir), "%s/Library/Logs/dev.anvl.local", home);
  snprintf(log_path, sizeof(log_path), "%s/launcher.log", log_dir);
  mkdir(log_dir, 0755);

  int log_fd = open(log_path, O_CREAT | O_WRONLY | O_APPEND, 0644);
  if (log_fd >= 0) {
    dup2(log_fd, STDOUT_FILENO);
    dup2(log_fd, STDERR_FILENO);
    dprintf(log_fd, "\\n[launcher] starting ANVL from Finder/Dock\\n");
  }

  char node_path[4096];
  char full_path[8192];
  const char *old_path = getenv("PATH");
  if (old_path == NULL) {
    old_path = "/usr/bin:/bin:/usr/sbin:/sbin";
  }
  snprintf(node_path, sizeof(node_path), "%s", "$NODE_BIN_DIR");
  snprintf(full_path, sizeof(full_path), "%s:/opt/homebrew/bin:/usr/local/bin:%s", node_path, old_path);
  setenv("PATH", full_path, 1);
  setenv("ZERO_NATIVE_PATH", "$ZERO_NATIVE_PATH", 1);

  if (chdir(root) != 0) {
    fprintf(stderr, "[launcher] chdir failed: %s\\n", strerror(errno));
    return 1;
  }

  setenv("ANVL_NATIVE_EXECUTABLE", "$NATIVE_EXECUTABLE", 1);
  setenv("ANVL_APP_BUNDLE", "$APP_DIR", 1);
  execl("/bin/bash", "bash", "$ROOT_DIR/script/run-anvl-mac.sh", (char *)NULL);
  fprintf(stderr, "[launcher] exec failed: %s\\n", strerror(errno));
  return 1;
}
EOF

clang "$LAUNCHER_SOURCE" -o "$EXECUTABLE"
rm -f "$LAUNCHER_SOURCE"
chmod +x "$EXECUTABLE"

cat >"$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>dev.anvl.local</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
EOF

if [[ ! -s "$CUSTOM_ICON" ]]; then
  echo "Missing required app icon: $CUSTOM_ICON" >&2
  exit 1
fi

cp "$CUSTOM_ICON" "$RESOURCES_DIR/icon.icns"
cat >>"$CONTENTS_DIR/Info.plist" <<EOF
  <key>CFBundleIconFile</key>
  <string>icon</string>
EOF

cat >>"$CONTENTS_DIR/Info.plist" <<EOF
</dict>
</plist>
EOF

echo "Created $APP_DIR"
