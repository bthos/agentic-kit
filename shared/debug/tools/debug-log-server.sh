#!/usr/bin/env bash
# Degraded debug log server — used when python3 is unavailable.
# Accepts POSTs to /log /console /network via nc and appends raw JSON bodies
# (one per line) to <investigation>/runtime.jsonl. No /tail, no /stream — the
# agent reads runtime.jsonl directly via `tail -n` or `tail -F`.
#
# Usage: debug-log-server.sh --investigation <dir> [--port 0]

set -euo pipefail

INV=""
PORT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --investigation) INV="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$INV" ] || [ ! -d "$INV" ]; then
  echo "ERROR: --investigation must point to an existing dir" >&2
  exit 2
fi

if ! command -v nc >/dev/null 2>&1; then
  echo "ERROR: nc (netcat) not found — install netcat or use debug-log-server.py instead" >&2
  exit 3
fi

RUNTIME="$INV/runtime.jsonl"
SERVER_JSON="$INV/server.json"
SERVER_PID="$INV/server.pid"

# Pick a free port if 0 was requested.
if [ "$PORT" = "0" ]; then
  PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()' 2>/dev/null || echo "")
  if [ -z "$PORT" ]; then
    PORT=49152
    while ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$PORT$"; do
      PORT=$((PORT + 1))
    done
  fi
fi

START_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$SERVER_JSON" <<JSON
{
  "port": $PORT,
  "pid": $$,
  "host": "127.0.0.1",
  "started": "$START_TS",
  "mode": "bash-fallback"
}
JSON
echo $$ > "$SERVER_PID"

cleanup() {
  STOP_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # Append `stopped` field (lightweight, doesn't need jq).
  tmp="$SERVER_JSON.tmp"
  awk -v s="$STOP_TS" 'BEGIN{added=0} /^\}/ && !added {print "  ,\"stopped\": \"" s "\""; added=1} {print}' "$SERVER_JSON" > "$tmp" && mv "$tmp" "$SERVER_JSON"
  rm -f "$SERVER_PID"
}
trap cleanup EXIT INT TERM

echo "debug-log-server (bash fallback) listening on 127.0.0.1:$PORT  (investigation=$(basename "$INV"))"

# Minimal HTTP loop: read request, extract body, append to runtime.jsonl, reply 200.
while true; do
  nc -l 127.0.0.1 "$PORT" >/dev/null 2>/tmp/debug.req.$$ <<EOF || true
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 11
Connection: close

{"ok":true}
EOF
  # Extract body (after blank line) from the captured request.
  if [ -s /tmp/debug.req.$$ ]; then
    awk 'BEGIN{body=0} /^\r?$/{body=1;next} body{print}' /tmp/debug.req.$$ >> "$RUNTIME" || true
    echo "" >> "$RUNTIME"
  fi
  rm -f /tmp/debug.req.$$
done
