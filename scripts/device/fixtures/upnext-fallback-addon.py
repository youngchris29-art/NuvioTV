#!/usr/bin/env python3
"""A one-file Stremio add-on for the Up Next auto-play fallback device pass.

Purpose: serves a fake series "Up Next Fixture" (zzupnext, S1E1..E6) and a fake movie
(zzupnext-movie) whose streams mix a direct URL with dead debrid and dead torrent entries, so the
device pass can watch Up Next / auto-play fall through failing sources to a playable one.
Used by the upstream-ports device pass A (docs/device-pass-upstream-ports-a-2026-11-16.md, P2/P3;
the Up Next fallback rows, and the --late-only instance for the late-arriving-stream rows).
Everything is made up: info hashes are sha1 of a fixture string (TorBox createtorrent runs with
add_only_if_cached=true, so nothing is ever added to an account), the video URL is the local
smoke file you pass with --media. No secrets, no real titles (idPrefixes ["zzupnext"]).

    python3 scripts/device/fixtures/upnext-fallback-addon.py [port] [--bind ADDR] [--media URL]
        [--id ID] [--name NAME] [--late-only SECONDS] [--salt STR]
    -> http://<mac-lan-ip>:<port>/manifest.json   (default bind 0.0.0.0, port 8771)

Per episode (main instance): ep1, ep3 Direct. ep2: dead debrid a1..a4 then Direct. ep4: dead
debrid b1, b2 then Direct. ep5: Direct then a dead torrent. ep6: dead debrid c1 only. Movie: Direct.
--late-only S answers only zzupnext:1:6 (one Direct "Late 720p" after sleeping S seconds); every
other stream id gets {"streams": []} at once. Run it with its own --id/--name.
Log: one line per request (method, path, what was served) on stderr, flushed. Ctrl-C / SIGTERM stops it.
"""
import hashlib
import json
import signal
import sys
import threading
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8771
BIND = "0.0.0.0"
MEDIA = "http://127.0.0.1:8011/upnext-150s.mkv"
ADDON_ID = "org.nuviotv.fixture.upnext"
NAME = "Up Next fixture"
LATE_ONLY = None
SALT = "fx"
args = sys.argv[1:]
if args and args[0].isdigit():
    PORT = int(args.pop(0))
while args:
    flag = args.pop(0)
    if flag == "--bind" and args:
        BIND = args.pop(0)
    elif flag == "--media" and args:
        MEDIA = args.pop(0)
    elif flag == "--id" and args:
        ADDON_ID = args.pop(0)
    elif flag == "--name" and args:
        NAME = args.pop(0)
    elif flag == "--late-only" and args:
        LATE_ONLY = float(args.pop(0))
    elif flag == "--salt" and args:
        SALT = args.pop(0)
    elif flag.isdigit():
        PORT = int(flag)
    else:
        sys.exit(f"unknown argument: {flag}")

SERIES_ID = "zzupnext"
MOVIE_ID = "zzupnext-movie"
LATE_ID = "zzupnext:1:6"

MANIFEST = {
    "id": ADDON_ID,
    "version": "1.0.0",
    "name": NAME,
    "description": "Device fixture: Up Next fallback streams (direct, dead debrid, dead torrent).",
    "resources": ["catalog", "meta", "stream"],
    "types": ["series", "movie"],
    "idPrefixes": ["zzupnext"],
    "catalogs": [{"type": "series", "id": "zzupnext-fixture", "name": "Up Next fixture (fixture)"}],
    "behaviorHints": {"configurable": False, "configurationRequired": False},
}

SERIES_META = {
    "id": SERIES_ID,
    "type": "series",
    "name": "Up Next Fixture",
    "description": "Fixture series for the Up Next fallback pass.",
    "releaseInfo": "2020",
    "videos": [
        {
            "id": f"{SERIES_ID}:1:{n}",
            "title": f"Fixture Episode {n}",
            "season": 1,
            "episode": n,
            "released": f"2020-01-0{n}T00:00:00.000Z",
            "runtime": "2 min",
        }
        for n in range(1, 7)
    ],
}
MOVIE_META = {
    "id": MOVIE_ID,
    "type": "movie",
    "name": "Up Next Fixture Movie",
    "description": "Fixture movie for the Up Next fallback pass.",
    "releaseInfo": "2020",
    "runtime": "2 min",
}
CATALOG = {"metas": [
    {"id": SERIES_ID, "type": "series", "name": SERIES_META["name"]},
    {"id": MOVIE_ID, "type": "movie", "name": MOVIE_META["name"]},
]}


def direct(name="Fixture 720p", title="Direct 720p"):
    return {"name": name, "title": title, "url": MEDIA}


def dead_debrid(n, k):
    h = hashlib.sha1(f"{SALT}-{n}-{k}".encode()).hexdigest()
    return {
        "name": "Fixture 2160p",
        "title": f"Dead debrid {SALT}{k} 2160p REMUX",
        "infoHash": h,
        "clientResolve": {
            "type": "debrid", "service": "torbox", "isCached": True, "infoHash": h, "fileIdx": 0,
            "filename": f"Up.Next.Fixture.S01E0{n}.2160p.REMUX.mkv", "season": 1, "episode": n,
        },
    }


def dead_torrent(n, k):
    return {"name": "Fixture 480p", "title": f"Dead torrent {k} 480p",
            "infoHash": hashlib.sha1(f"{SALT}-{n}-{k}".encode()).hexdigest()}


def streams_for(vid):
    if vid == MOVIE_ID:
        return [direct()]
    if not vid.startswith(SERIES_ID + ":1:"):
        return []
    n = vid.rsplit(":", 1)[1]
    if n in ("1", "3"):
        return [direct()]
    if n == "2":
        return [dead_debrid(2, f"a{i}") for i in range(1, 5)] + [direct()]
    if n == "4":
        return [dead_debrid(4, "b1"), dead_debrid(4, "b2"), direct()]
    if n == "5":
        return [direct(), dead_torrent(5, "e1")]
    if n == "6":
        return [dead_debrid(6, "c1")]
    return []


class Handler(BaseHTTPRequestHandler):
    def _send(self, payload, note, status=200):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        sys.stderr.write(f"{datetime.now():%H:%M:%S} [upnext-fallback] {self.command} {self.path} -> {status} {note}\n")
        sys.stderr.flush()

    def do_OPTIONS(self):  # noqa: N802
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_GET(self):  # noqa: N802
        parts = self.path.split("?", 1)[0].lstrip("/").split("/")
        if parts == ["manifest.json"]:
            return self._send(MANIFEST, "manifest")
        if len(parts) == 3 and parts[0] == "catalog":
            return self._send(CATALOG, "catalog (2 items)")
        if len(parts) == 3 and parts[0] == "meta" and parts[2].endswith(".json"):
            vid = parts[2][:-5].replace("%3A", ":")
            if vid == SERIES_ID:
                return self._send({"meta": SERIES_META}, "meta series")
            if vid == MOVIE_ID:
                return self._send({"meta": MOVIE_META}, "meta movie")
            return self._send({"meta": None}, "meta unknown", 404)
        if len(parts) == 3 and parts[0] == "stream" and parts[2].endswith(".json"):
            vid = parts[2][:-5].replace("%3A", ":")
            if LATE_ONLY is not None:
                if vid != LATE_ID:
                    return self._send({"streams": []}, f"late-only: empty for {vid}")
                time.sleep(LATE_ONLY)
                return self._send({"streams": [direct("Late 720p", "Late 720p")]},
                                  f"late-only: Late 720p after {LATE_ONLY:g}s")
            streams = streams_for(vid)
            return self._send({"streams": streams}, f"{len(streams)} streams: " +
                              ", ".join(s["title"] for s in streams))
        return self._send({"error": "not found"}, "not found", 404)

    def log_message(self, fmt, *a):
        pass


def main():
    server = ThreadingHTTPServer((BIND, PORT), Handler)
    server.daemon_threads = True

    def stop(*_):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    sys.stderr.write(f"[upnext-fallback] serving on {BIND}:{PORT} id={ADDON_ID} name={NAME!r} "
                     f"media={MEDIA} late-only={LATE_ONLY}\n")
    sys.stderr.flush()
    server.serve_forever()
    server.server_close()


if __name__ == "__main__":
    main()
