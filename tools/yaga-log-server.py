#!/usr/bin/env python3
"""Yaga local debug log server.

Captures runtime probes from instrumented code over loopback HTTP, appends to
runtime.jsonl in the investigation directory, and exposes a tail/stream/shutdown
API for the @yaga agent.

Usage:
    python3 yaga-log-server.py --investigation .akt/debug/2026-05-21-bug-slug [--port 0]

Endpoints (all on 127.0.0.1):
    POST /log      arbitrary JSON probe payload
    POST /console  browser console hook: {level, args}
    POST /network  browser fetch/xhr hook: {url, method, status, ms}
    GET  /tail?n=N latest N JSONL entries (default 200)
    GET  /stream   Server-Sent Events live tail
    POST /shutdown graceful stop

Security:
    Binds 127.0.0.1 only. No auth (loopback-only by design).
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import signal
import socket
import sys
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

INV_DIR: Path
RUNTIME_LOG: Path
SERVER_JSON: Path
SERVER_PID: Path
SUBSCRIBERS: list[queue.Queue[str]] = []
SUB_LOCK = threading.Lock()
WRITE_LOCK = threading.Lock()
SHUTDOWN_EVENT = threading.Event()


def _iso_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def _append(entry: dict[str, Any]) -> None:
    if "ts" not in entry:
        entry["ts"] = _iso_now()
    line = json.dumps(entry, ensure_ascii=False, separators=(",", ":"))
    with WRITE_LOCK:
        with RUNTIME_LOG.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    with SUB_LOCK:
        for q in list(SUBSCRIBERS):
            try:
                q.put_nowait(line)
            except queue.Full:
                pass


def _tail(n: int) -> list[str]:
    if not RUNTIME_LOG.exists():
        return []
    with RUNTIME_LOG.open("r", encoding="utf-8") as f:
        lines = f.readlines()
    return [l.rstrip("\n") for l in lines[-n:]]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args: Any) -> None:  # silence access log
        return

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("content-length", "0") or "0")
        if not length:
            return {}
        raw = self.rfile.read(length)
        try:
            data = json.loads(raw.decode("utf-8"))
            return data if isinstance(data, dict) else {"raw": data}
        except Exception:
            return {"raw": raw.decode("utf-8", errors="replace")}

    def _send_json(self, status: int, payload: Any) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.send_header("access-control-allow-origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # browser CORS preflight
        self.send_response(204)
        self.send_header("access-control-allow-origin", "*")
        self.send_header("access-control-allow-methods", "POST, GET, OPTIONS")
        self.send_header("access-control-allow-headers", "content-type")
        self.end_headers()

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        if path == "/log":
            entry = self._read_json()
            entry.setdefault("kind", "log")
            _append(entry)
            self._send_json(200, {"ok": True})
        elif path == "/console":
            entry = self._read_json()
            entry["kind"] = "console"
            _append(entry)
            self._send_json(200, {"ok": True})
        elif path == "/network":
            entry = self._read_json()
            entry["kind"] = "network"
            _append(entry)
            self._send_json(200, {"ok": True})
        elif path == "/shutdown":
            self._send_json(200, {"ok": True, "stopping": True})
            threading.Thread(target=_stop, daemon=True).start()
        else:
            self._send_json(404, {"error": "not found", "path": path})

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/tail":
            qs = parse_qs(parsed.query)
            try:
                n = int(qs.get("n", ["200"])[0])
            except ValueError:
                n = 200
            n = max(1, min(n, 5000))
            lines = _tail(n)
            self._send_json(200, {"count": len(lines), "entries": [json.loads(l) for l in lines if l.strip()]})
        elif parsed.path == "/stream":
            self.send_response(200)
            self.send_header("content-type", "text/event-stream")
            self.send_header("cache-control", "no-cache")
            self.send_header("connection", "keep-alive")
            self.end_headers()
            q: queue.Queue[str] = queue.Queue(maxsize=1000)
            with SUB_LOCK:
                SUBSCRIBERS.append(q)
            try:
                while not SHUTDOWN_EVENT.is_set():
                    try:
                        line = q.get(timeout=15)
                        self.wfile.write(f"data: {line}\n\n".encode("utf-8"))
                        self.wfile.flush()
                    except queue.Empty:
                        try:
                            self.wfile.write(b": keep-alive\n\n")
                            self.wfile.flush()
                        except Exception:
                            break
                    except Exception:
                        break
            finally:
                with SUB_LOCK:
                    if q in SUBSCRIBERS:
                        SUBSCRIBERS.remove(q)
        elif parsed.path == "/health":
            self._send_json(200, {"ok": True, "investigation": str(INV_DIR)})
        else:
            self._send_json(404, {"error": "not found", "path": parsed.path})


HTTPD: ThreadingHTTPServer | None = None


def _stop() -> None:
    SHUTDOWN_EVENT.set()
    if HTTPD is not None:
        HTTPD.shutdown()
    _mark_stopped()


def _mark_stopped() -> None:
    try:
        meta = json.loads(SERVER_JSON.read_text(encoding="utf-8"))
    except Exception:
        meta = {}
    meta["stopped"] = _iso_now()
    SERVER_JSON.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    try:
        SERVER_PID.unlink()
    except FileNotFoundError:
        pass


def _signal(_sig: int, _frm: Any) -> None:
    _stop()


def main() -> int:
    parser = argparse.ArgumentParser(description="Yaga local debug log server")
    parser.add_argument("--investigation", required=True, help="Path to .akt/debug/<slug>/ directory")
    parser.add_argument("--port", type=int, default=0, help="TCP port (0 = ephemeral)")
    parser.add_argument("--host", default="127.0.0.1", help="bind host (DO NOT change from 127.0.0.1)")
    args = parser.parse_args()

    global INV_DIR, RUNTIME_LOG, SERVER_JSON, SERVER_PID, HTTPD
    INV_DIR = Path(args.investigation).resolve()
    if not INV_DIR.is_dir():
        print(f"ERROR: investigation dir does not exist: {INV_DIR}", file=sys.stderr)
        return 2
    if args.host != "127.0.0.1":
        print("ERROR: refusing to bind non-loopback host", file=sys.stderr)
        return 3

    RUNTIME_LOG = INV_DIR / "runtime.jsonl"
    SERVER_JSON = INV_DIR / "server.json"
    SERVER_PID = INV_DIR / "server.pid"

    # Best-effort: detect stale pidfile.
    if SERVER_PID.exists():
        try:
            old_pid = int(SERVER_PID.read_text().strip())
            try:
                os.kill(old_pid, 0)
                print(f"ERROR: server already running for this investigation (pid {old_pid})", file=sys.stderr)
                return 4
            except OSError:
                SERVER_PID.unlink()
        except Exception:
            SERVER_PID.unlink()

    HTTPD = ThreadingHTTPServer((args.host, args.port), Handler)
    port = HTTPD.server_address[1]

    SERVER_JSON.write_text(json.dumps({
        "port": port,
        "pid": os.getpid(),
        "host": args.host,
        "started": _iso_now(),
        "investigation": str(INV_DIR),
    }, indent=2), encoding="utf-8")
    SERVER_PID.write_text(str(os.getpid()), encoding="utf-8")

    signal.signal(signal.SIGINT, _signal)
    signal.signal(signal.SIGTERM, _signal)

    print(f"yaga-log-server listening on http://{args.host}:{port}  (investigation={INV_DIR.name})", flush=True)
    try:
        HTTPD.serve_forever()
    finally:
        _mark_stopped()
    return 0


if __name__ == "__main__":
    sys.exit(main())
