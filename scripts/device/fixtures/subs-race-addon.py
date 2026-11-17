#!/usr/bin/env python3
"""A one-file Stremio add-on that answers subtitle requests with one fixture track, optionally late.

Purpose: device fixture for the subtitle-fetch race rows of the upstream-ports device pass A
(docs/device-pass-upstream-ports-a-2026-11-16.md, P2/P3): one instance answers at once with a
track, another answers only after a delay with an empty list, so the player's subtitle fetch race
(fast add-on vs slow add-on) can be observed. Only declares idPrefixes ["zzupnext"].

    python3 scripts/device/fixtures/subs-race-addon.py [port] [--bind ADDR] [--delay S] [--empty]
        [--id ID] [--name NAME]
    -> http://<mac-lan-ip>:<port>/manifest.json   (default bind 0.0.0.0, port 8773)

/subtitles/<type>/<id>.json and /subtitles/<type>/<id>/<extra>.json sleep S seconds (default 0),
then return one English track "race-<name>" (url = /race.srt on the host the request used), or
{"subtitles": []} with --empty. /race.srt has three cues, "Race fixture line 1/2/3", at 0, 60 and
120 s (each 30 s long), spread over 150 s.
Log: one line per request (method, path, what was served) on stderr, flushed. Ctrl-C / SIGTERM stops it.
"""
import json
import re
import signal
import sys
import threading
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8773
BIND = "0.0.0.0"
DELAY = 0.0
EMPTY = False
ADDON_ID = "org.nuviotv.fixture.subsrace"
NAME = "Subs Race fixture"
args = sys.argv[1:]
if args and args[0].isdigit():
    PORT = int(args.pop(0))
while args:
    flag = args.pop(0)
    if flag == "--bind" and args:
        BIND = args.pop(0)
    elif flag == "--delay" and args:
        DELAY = float(args.pop(0))
    elif flag == "--empty":
        EMPTY = True
    elif flag == "--id" and args:
        ADDON_ID = args.pop(0)
    elif flag == "--name" and args:
        NAME = args.pop(0)
    elif flag.isdigit():
        PORT = int(flag)
    else:
        sys.exit(f"unknown argument: {flag}")

MANIFEST = {
    "id": ADDON_ID,
    "version": "1.0.0",
    "name": NAME,
    "description": f"Device fixture: subtitles after {DELAY:g}s" + (", always empty." if EMPTY else "."),
    "resources": ["subtitles"],
    "types": ["series", "movie"],
    "idPrefixes": ["zzupnext"],
    "catalogs": [],
    "behaviorHints": {"configurable": False, "configurationRequired": False},
}


def srt():
    def ts(s):
        return f"{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d},000"
    cues = []
    for i, start in enumerate((0, 60, 120), 1):
        cues.append(f"{i}\n{ts(start)} --> {ts(start + 30)}\nRace fixture line {i}\n")
    return "\n".join(cues).encode("utf-8")


SRT = srt()
SUB_RE = re.compile(r"^/subtitles/([^/]+)/([^/]+?)(?:\.json|/[^/]+\.json)$")


class Handler(BaseHTTPRequestHandler):
    def _log(self, status, note):
        sys.stderr.write(f"{datetime.now():%H:%M:%S} [subs-race] {self.command} {self.path} -> {status} {note}\n")
        sys.stderr.flush()

    def _send(self, body, ctype, note, status=200):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        self._log(status, note)

    def _json(self, payload, note, status=200):
        self._send(json.dumps(payload, ensure_ascii=False).encode("utf-8"),
                   "application/json; charset=utf-8", note, status)

    def do_OPTIONS(self):  # noqa: N802
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_GET(self):  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path == "/manifest.json":
            return self._json(MANIFEST, "manifest")
        if path == "/race.srt":
            return self._send(SRT, "application/x-subrip; charset=utf-8", "race.srt (3 cues)")
        if SUB_RE.match(path):
            time.sleep(DELAY)
            if EMPTY:
                return self._json({"subtitles": []}, f"empty subtitles after {DELAY:g}s")
            host = self.headers.get("Host") or f"127.0.0.1:{PORT}"
            track = {"id": f"race-{NAME}", "url": f"http://{host}/race.srt", "lang": "eng"}
            return self._json({"subtitles": [track]}, f"1 subtitle after {DELAY:g}s")
        return self._json({"error": "not found"}, "not found", 404)

    def log_message(self, fmt, *a):
        pass


def main():
    server = ThreadingHTTPServer((BIND, PORT), Handler)
    server.daemon_threads = True

    def stop(*_):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    sys.stderr.write(f"[subs-race] serving on {BIND}:{PORT} id={ADDON_ID} name={NAME!r} "
                     f"delay={DELAY:g}s empty={EMPTY}\n")
    sys.stderr.flush()
    server.serve_forever()
    server.server_close()


if __name__ == "__main__":
    main()
