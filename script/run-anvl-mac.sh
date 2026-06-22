#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ANVL_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RUNTIME_ROOT="${ANVL_RUNTIME_ROOT:-$ROOT_DIR}"
DESKTOP_DIR="$ROOT_DIR/desktop"
SERVER_ROOT="$RUNTIME_ROOT/server"
CLIENT_ROOT="$RUNTIME_ROOT/client"
NODE_BIN="${ANVL_NODE_BIN:-node}"
BUNDLED_RUNTIME_ROOT="${ANVL_BUNDLED_RUNTIME_ROOT:-}"
BUNDLED_NODE="${ANVL_BUNDLED_NODE:-}"
RUNTIME_SESSION_DIR=""

CLIENT_HOST="${ANVL_CLIENT_HOST:-127.0.0.1}"
CLIENT_PORT="${ANVL_CLIENT_PORT:-4350}"
CLIENT_HMR_PORT="${ANVL_HMR_PORT:-4351}"
SERVER_HOST="${ANVL_SERVER_HOST:-127.0.0.1}"
SERVER_PORT="${ANVL_SERVER_PORT:-4000}"

CLIENT_URL="http://${CLIENT_HOST}:${CLIENT_PORT}/"
SERVER_URL="http://${SERVER_HOST}:${SERVER_PORT}"
SERVER_HEALTH_URL="${SERVER_URL}/health"
NATIVE_EXECUTABLE="${ANVL_NATIVE_EXECUTABLE:-$DESKTOP_DIR/zig-out/bin/ANVL}"
NATIVE_FILE_TOKEN="${ANVL_NATIVE_FILE_TOKEN:-}"

SERVER_PID=""
CLIENT_PID=""

log_step() {
  echo "[launcher] $1"
}

cleanup() {
  if [[ -n "$CLIENT_PID" ]] && kill -0 "$CLIENT_PID" >/dev/null 2>&1; then
    kill "$CLIENT_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$RUNTIME_SESSION_DIR" ]] && [[ -d "$RUNTIME_SESSION_DIR" ]]; then
    rm -rf "$RUNTIME_SESSION_DIR" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

port_in_use() {
  local _host="$1"
  local port="$2"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

wait_for_port() {
  local label="$1"
  local host="$2"
  local port="$3"
  local timeout_seconds="${4:-40}"

  for _ in $(seq 1 "$timeout_seconds"); do
    if port_in_use "$host" "$port"; then
      return 0
    fi
    sleep 1
  done

  echo "Timed out waiting for ${label} on ${host}:${port}." >&2
  return 1
}

wait_for_http() {
  local label="$1"
  local url="$2"
  local timeout_seconds="${3:-60}"

  for _ in $(seq 1 "$timeout_seconds"); do
    if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "Timed out waiting for ${label} at ${url}." >&2
  return 1
}

stop_port_processes() {
  local label="$1"
  local host="$2"
  local port="$3"
  local pids
  local candidates
  local parent_pid

  pids="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -z "$pids" ]]; then
    return 0
  fi

  echo "Stopping existing ${label} on port ${port}"
  candidates="$pids"
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    parent_pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
    if [[ -n "$parent_pid" ]] && [[ "$parent_pid" != "1" ]]; then
      candidates="${candidates}"$'\n'"${parent_pid}"
    fi
  done <<<"$pids"

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill "$pid" >/dev/null 2>&1 || true
  done <<<"$(printf "%s\n" "$candidates" | sort -u)"

  sleep 1

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill "$pid" >/dev/null 2>&1 || true
  done <<<"$pids"

  for _ in $(seq 1 10); do
    if ! port_in_use "$host" "$port"; then
      return 0
    fi
    sleep 1
  done

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill -9 "$pid" >/dev/null 2>&1 || true
  done <<<"$(printf "%s\n" "$candidates" | sort -u)"
}

verify_native_file_token() {
  local status
  status="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 3 \
    -X POST \
    -H "Content-Type: application/json" \
    -H "x-anvl-native-token: ${NATIVE_FILE_TOKEN}" \
    --data '{"paths":[],"type":"image"}' \
    "${SERVER_URL}/api/native-files/read" || true)"

  [[ "$status" == "200" ]]
}

wait_for_client_token() {
  local timeout_seconds="${1:-60}"

  for _ in $(seq 1 "$timeout_seconds"); do
    if curl -fsS --max-time 2 "$CLIENT_URL" | grep -F "$NATIVE_FILE_TOKEN" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

start_server() {
  echo "Starting ANVL server on ${SERVER_URL}"
  (
    cd /
    HOST="$SERVER_HOST" PORT="$SERVER_PORT" ANVL_NATIVE_FILE_TOKEN="$NATIVE_FILE_TOKEN" "$NODE_BIN" "$SERVER_ROOT/index.js"
  ) &
  SERVER_PID="$!"

  wait_for_port "ANVL server" "$SERVER_HOST" "$SERVER_PORT"
  wait_for_http "ANVL server" "$SERVER_HEALTH_URL"
  if ! verify_native_file_token; then
    echo "Started ANVL server, but native upload token verification failed." >&2
    exit 1
  fi
}

start_client() {
  echo "Starting ANVL client on ${CLIENT_URL}"
  (
    cd /
    ANVL_HMR_PORT="$CLIENT_HMR_PORT" NUXT_DEVTOOLS=false NUXT_PUBLIC_API_BASE="$SERVER_URL" NUXT_PUBLIC_NATIVE_FILE_TOKEN="$NATIVE_FILE_TOKEN" "$NODE_BIN" "$CLIENT_ROOT/node_modules/nuxt/bin/nuxt.mjs" dev "$CLIENT_ROOT" --host "$CLIENT_HOST" --port "$CLIENT_PORT"
  ) &
  CLIENT_PID="$!"

  wait_for_port "ANVL client" "$CLIENT_HOST" "$CLIENT_PORT"
  wait_for_http "ANVL client" "$CLIENT_URL"
  if ! wait_for_client_token; then
    echo "Started ANVL client, but native upload token verification failed." >&2
    exit 1
  fi
}

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

prepare_packaged_runtime() {
  if [[ -z "$BUNDLED_RUNTIME_ROOT" ]]; then
    return 0
  fi

  if [[ ! -d "$BUNDLED_RUNTIME_ROOT" ]]; then
    echo "Bundled ANVL runtime not found at $BUNDLED_RUNTIME_ROOT." >&2
    exit 1
  fi

  if [[ ! -x "$BUNDLED_NODE" ]]; then
    echo "Bundled Node executable not found at $BUNDLED_NODE." >&2
    exit 1
  fi

  if ! command -v ditto >/dev/null 2>&1; then
    echo "Missing required command: ditto" >&2
    exit 1
  fi

  local support_root
  support_root="${HOME}/Library/Application Support/ANVL"
  mkdir -p "$support_root"
  RUNTIME_SESSION_DIR="$(mktemp -d "$support_root/runtime.XXXXXX")"

  ditto "$BUNDLED_RUNTIME_ROOT" "$RUNTIME_SESSION_DIR/app"
  cp "$BUNDLED_NODE" "$RUNTIME_SESSION_DIR/node"
  chmod +x "$RUNTIME_SESSION_DIR/node"

  RUNTIME_ROOT="$RUNTIME_SESSION_DIR/app"
  SERVER_ROOT="$RUNTIME_ROOT/server"
  CLIENT_ROOT="$RUNTIME_ROOT/client"
  NODE_BIN="$RUNTIME_SESSION_DIR/node"
}

SHOULD_BUILD_NATIVE=1
if [[ -n "${ANVL_APP_BUNDLE:-}" ]] && [[ -x "$NATIVE_EXECUTABLE" ]]; then
  SHOULD_BUILD_NATIVE=0
fi

if [[ "$SHOULD_BUILD_NATIVE" == "1" ]] && [[ ! -f "$DESKTOP_DIR/build.zig" ]]; then
  echo "Zero Native project not found at $DESKTOP_DIR." >&2
  echo "Run: zero-native init desktop --frontend vue" >&2
  exit 1
fi

prepare_packaged_runtime

if [[ ! -f "$SERVER_ROOT/index.js" ]]; then
  echo "ANVL server runtime not found at $SERVER_ROOT." >&2
  exit 1
fi

if [[ ! -f "$CLIENT_ROOT/node_modules/nuxt/bin/nuxt.mjs" ]]; then
  echo "ANVL client runtime not found at $CLIENT_ROOT." >&2
  exit 1
fi

require_command "$NODE_BIN"
require_command curl
require_command lsof
require_command uuidgen

if [[ -z "$NATIVE_FILE_TOKEN" ]]; then
  NATIVE_FILE_TOKEN="$(uuidgen | tr -d '-')"
fi
export NATIVE_FILE_TOKEN
export NODE_DISABLE_COMPILE_CACHE=1
log_step "Prepared native session"

if [[ "$SHOULD_BUILD_NATIVE" == "0" ]]; then
  log_step "Using packaged native executable"
else
  log_step "Native executable will be rebuilt"
fi

if [[ "$SHOULD_BUILD_NATIVE" == "1" ]]; then
  require_command zig

  ZERO_NATIVE_PATH="$(resolve_zero_native_path || true)"
  if [[ ! -f "$ZERO_NATIVE_PATH/src/root.zig" ]]; then
    echo "Zero Native framework not found at: $ZERO_NATIVE_PATH" >&2
    echo "Install it with: npm install -g zero-native" >&2
    echo "Or set ZERO_NATIVE_PATH=/path/to/zero-native before running this script." >&2
    exit 1
  fi
fi

log_step "Checking ANVL server on ${SERVER_URL}"
if port_in_use "$SERVER_HOST" "$SERVER_PORT"; then
  if curl -fsS --max-time 2 "$SERVER_HEALTH_URL" >/dev/null 2>&1; then
    if verify_native_file_token; then
      echo "Reusing existing server on ${SERVER_URL}"
    else
      echo "Existing ANVL server has an old native upload token."
      stop_port_processes "ANVL server" "$SERVER_HOST" "$SERVER_PORT"
      start_server
    fi
  else
    echo "Port ${SERVER_PORT} is already in use, but ${SERVER_HEALTH_URL} does not look like ANVL." >&2
    echo "Stop the process using ${SERVER_HOST}:${SERVER_PORT} or set ANVL_SERVER_PORT." >&2
    exit 1
  fi
else
  start_server
fi

log_step "Checking ANVL client on ${CLIENT_URL}"
if port_in_use "$CLIENT_HOST" "$CLIENT_PORT"; then
  wait_for_http "ANVL client" "$CLIENT_URL"
  if wait_for_client_token 3; then
    echo "Reusing existing client on ${CLIENT_URL}"
  else
    echo "Existing ANVL client has an old native upload token."
    stop_port_processes "ANVL client" "$CLIENT_HOST" "$CLIENT_PORT"
    start_client
  fi
else
  if port_in_use "$CLIENT_HOST" "$CLIENT_HMR_PORT"; then
    echo "Port ${CLIENT_HMR_PORT} is already in use. Stop the existing process or set ANVL_HMR_PORT." >&2
    exit 1
  fi

  start_client
fi

echo "Launching ANVL desktop shell"
if [[ "$SHOULD_BUILD_NATIVE" == "1" ]]; then
  (
    cd "$DESKTOP_DIR"
    zig build -Dzero-native-path="$ZERO_NATIVE_PATH"
  )

  if [[ "${ANVL_NATIVE_EXECUTABLE:-}" != "" ]]; then
    cp "$DESKTOP_DIR/zig-out/bin/ANVL" "$ANVL_NATIVE_EXECUTABLE"
    chmod +x "$ANVL_NATIVE_EXECUTABLE"
  fi
else
  echo "Using bundled ANVL native shell"
fi

NATIVE_WORKDIR="/"
if [[ "$SHOULD_BUILD_NATIVE" == "1" ]]; then
  NATIVE_WORKDIR="$DESKTOP_DIR"
fi

(
  cd "$NATIVE_WORKDIR"
  ZERO_NATIVE_FRONTEND_URL="$CLIENT_URL" "$NATIVE_EXECUTABLE"
)
