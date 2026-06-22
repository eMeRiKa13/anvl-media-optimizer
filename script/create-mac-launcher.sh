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
RUNTIME_SCRIPT="$RESOURCES_DIR/run-anvl-mac.sh"
PACKAGED_APP_DIR="$RESOURCES_DIR/app"
PACKAGED_NODE="$RESOURCES_DIR/node"
CUSTOM_ICON="$ROOT_DIR/desktop/assets/logo.icns"
BUILD_VERSION="$(date +%Y%m%d%H%M%S)"
NODE_BIN_DIR="$(dirname "$(command -v node)")"
NODE_BIN="$(command -v node)"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    echo "Install Zero Native prerequisites first: Zig 0.16+ and the zero-native CLI." >&2
    exit 1
  fi
}

resolve_zero_native_path() {
  local candidates=()
  local npm_root
  local zero_native_bin
  local node_prefix
  local candidate

  if [[ -n "${ZERO_NATIVE_PATH:-}" ]]; then
    candidates+=("$ZERO_NATIVE_PATH")
  fi

  if command -v npm >/dev/null 2>&1; then
    npm_root="$(npm root -g 2>/dev/null || true)"
    if [[ -n "$npm_root" ]]; then
      candidates+=("$npm_root/zero-native")
    fi
  fi

  if command -v zero-native >/dev/null 2>&1; then
    zero_native_bin="$(command -v zero-native)"
    node_prefix="$(cd "$(dirname "$zero_native_bin")/.." && pwd)"
    candidates+=("$node_prefix/lib/node_modules/zero-native")
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate/src/root.zig" ]]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done

  return 1
}

require_command zig
require_command clang
require_command npm
require_command ditto

ZERO_NATIVE_PATH="$(resolve_zero_native_path || true)"
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
cp "$ROOT_DIR/script/run-anvl-mac.sh" "$RUNTIME_SCRIPT"
chmod +x "$RUNTIME_SCRIPT"
cp "$NODE_BIN" "$PACKAGED_NODE"
chmod +x "$PACKAGED_NODE"
mkdir -p "$PACKAGED_APP_DIR"
ditto "$ROOT_DIR/node_modules" "$PACKAGED_APP_DIR/node_modules"
ditto "$ROOT_DIR/client" "$PACKAGED_APP_DIR/client"
ditto "$ROOT_DIR/server" "$PACKAGED_APP_DIR/server"
rm -rf "$PACKAGED_APP_DIR/server/uploads" "$PACKAGED_APP_DIR/server/processed"

cat >"$LAUNCHER_SOURCE" <<EOF
#include <mach-o/dyld.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

static void parent_dir(char *path) {
  char *slash = strrchr(path, '/');
  if (slash == NULL) {
    snprintf(path, PATH_MAX, ".");
    return;
  }
  if (slash == path) {
    slash[1] = '\\0';
    return;
  }
  *slash = '\\0';
}

int main(void) {
  char executable_path[PATH_MAX];
  uint32_t executable_path_size = sizeof(executable_path);
  if (_NSGetExecutablePath(executable_path, &executable_path_size) != 0) {
    fprintf(stderr, "[launcher] executable path is too long\\n");
    return 1;
  }

  char resolved_executable[PATH_MAX];
  if (realpath(executable_path, resolved_executable) == NULL) {
    snprintf(resolved_executable, sizeof(resolved_executable), "%s", executable_path);
  }

  char macos_dir[PATH_MAX];
  char contents_dir[PATH_MAX];
  char app_dir[PATH_MAX];
  char resources_dir[PATH_MAX];
  char native_executable[PATH_MAX];
  char runtime_script[PATH_MAX];
  char bundled_runtime_root[PATH_MAX];
  char bundled_node[PATH_MAX];

  snprintf(macos_dir, sizeof(macos_dir), "%s", resolved_executable);
  parent_dir(macos_dir);
  snprintf(contents_dir, sizeof(contents_dir), "%s", macos_dir);
  parent_dir(contents_dir);
  snprintf(app_dir, sizeof(app_dir), "%s", contents_dir);
  parent_dir(app_dir);
  snprintf(resources_dir, sizeof(resources_dir), "%s/Resources", contents_dir);
  snprintf(native_executable, sizeof(native_executable), "%s/${APP_NAME}Native", macos_dir);
  snprintf(runtime_script, sizeof(runtime_script), "%s/run-anvl-mac.sh", resources_dir);
  snprintf(bundled_runtime_root, sizeof(bundled_runtime_root), "%s/app", resources_dir);
  snprintf(bundled_node, sizeof(bundled_node), "%s/node", resources_dir);

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

  if (chdir("/") != 0) {
    fprintf(stderr, "[launcher] chdir failed: %s\\n", strerror(errno));
    return 1;
  }

  setenv("ANVL_NATIVE_EXECUTABLE", native_executable, 1);
  setenv("ANVL_APP_BUNDLE", app_dir, 1);
  setenv("ANVL_BUNDLED_RUNTIME_ROOT", bundled_runtime_root, 1);
  setenv("ANVL_BUNDLED_NODE", bundled_node, 1);
  setenv("NODE_DISABLE_COMPILE_CACHE", "1", 1);

  pid_t pid = fork();
  if (pid < 0) {
    fprintf(stderr, "[launcher] fork failed: %s\\n", strerror(errno));
    return 1;
  }

  if (pid == 0) {
    execl("/bin/bash", "bash", runtime_script, (char *)NULL);
    fprintf(stderr, "[launcher] exec failed: %s\\n", strerror(errno));
    _exit(127);
  }

  int status = 0;
  if (waitpid(pid, &status, 0) < 0) {
    fprintf(stderr, "[launcher] wait failed: %s\\n", strerror(errno));
    return 1;
  }

  if (WIFEXITED(status)) {
    return WEXITSTATUS(status);
  }
  if (WIFSIGNALED(status)) {
    return 128 + WTERMSIG(status);
  }
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
  <key>NSDocumentsFolderUsageDescription</key>
  <string>ANVL needs access to its local project files when launched from this workspace.</string>
  <key>NSDesktopFolderUsageDescription</key>
  <string>ANVL needs access if this workspace is stored on the Desktop.</string>
  <key>NSDownloadsFolderUsageDescription</key>
  <string>ANVL saves processed files to Downloads from the macOS app.</string>
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
