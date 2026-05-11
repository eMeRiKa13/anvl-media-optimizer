#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="$ROOT_DIR/desktop"

CLIENT_HOST="${ANVL_CLIENT_HOST:-127.0.0.1}"
CLIENT_PORT="${ANVL_CLIENT_PORT:-4350}"
CLIENT_HMR_PORT="${ANVL_HMR_PORT:-4351}"
SERVER_HOST="${ANVL_SERVER_HOST:-127.0.0.1}"
SERVER_PORT="${ANVL_SERVER_PORT:-4000}"

CLIENT_URL="http://${CLIENT_HOST}:${CLIENT_PORT}/"
SERVER_URL="http://${SERVER_HOST}:${SERVER_PORT}"

SERVER_PID=""
CLIENT_PID=""

cleanup() {
  if [[ -n "$CLIENT_PID" ]] && kill -0 "$CLIENT_PID" >/dev/null 2>&1; then
    kill "$CLIENT_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

port_in_use() {
  local host="$1"
  local port="$2"
  (echo >"/dev/tcp/${host}/${port}") >/dev/null 2>&1
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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    echo "Install Zero Native prerequisites first: Zig 0.16+ and the zero-native CLI." >&2
    exit 1
  fi
}

if [[ ! -f "$DESKTOP_DIR/build.zig" ]]; then
  echo "Zero Native project not found at $DESKTOP_DIR." >&2
  echo "Run: zero-native init desktop --frontend vue" >&2
  exit 1
fi

require_command npm
require_command zig

if port_in_use "$SERVER_HOST" "$SERVER_PORT"; then
  echo "Reusing existing server on ${SERVER_URL}"
else
  echo "Starting ANVL server on ${SERVER_URL}"
  (
    cd "$ROOT_DIR"
    HOST="$SERVER_HOST" PORT="$SERVER_PORT" npm run dev --workspace=server
  ) &
  SERVER_PID="$!"

  wait_for_port "ANVL server" "$SERVER_HOST" "$SERVER_PORT"
fi

if port_in_use "$CLIENT_HOST" "$CLIENT_PORT"; then
  echo "Reusing existing client on ${CLIENT_URL}"
else
  if port_in_use "$CLIENT_HOST" "$CLIENT_HMR_PORT"; then
    echo "Port ${CLIENT_HMR_PORT} is already in use. Stop the existing process or set ANVL_HMR_PORT." >&2
    exit 1
  fi

  echo "Starting ANVL client on ${CLIENT_URL}"
  (
    cd "$ROOT_DIR"
    ANVL_HMR_PORT="$CLIENT_HMR_PORT" NUXT_DEVTOOLS=false NUXT_PUBLIC_API_BASE="$SERVER_URL" npm run dev --workspace=client
  ) &
  CLIENT_PID="$!"

  wait_for_port "ANVL client" "$CLIENT_HOST" "$CLIENT_PORT"
fi

echo "Launching ANVL desktop shell"
(
  cd "$DESKTOP_DIR"
  ZERO_NATIVE_FRONTEND_URL="$CLIENT_URL" zig build run
)
