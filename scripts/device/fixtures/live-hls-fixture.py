#!/usr/bin/env python3
"""Loopback live-HLS fixture for the open-bugs batch (BUG-243).

Segments first (once), next to this file, about 55 MB, not for the repo:
  mkdir -p seg && ffmpeg -f lavfi -i "testsrc2=size=640x360:rate=25" -f lavfi -i "sine=frequency=440:sample_rate=48000" \
    -t 900 -c:v libx264 -preset ultrafast -g 50 -keyint_min 50 -sc_threshold 0 -b:v 400k -c:a aac -b:a 64k \
    -f hls -hls_time 2 -hls_list_size 0 -hls_segment_filename "seg/s%04d.ts" seg/vod.m3u8
Play it with the Debug build: -debug.mpvSmokeURL http://<mac>:8765/live.m3u8 -debug.mpvSmokeEngine mpv
(simulator: 127.0.0.1; the box: the Mac's LAN address, through console.sh start <log> -- <args>).

Serves seg/s%04d.ts (2 s each) as a sliding-window LIVE playlist at /live.m3u8 (no ENDLIST),
and the same segments as a short VOD at /vod.m3u8 (first 15 segments, ENDLIST).
Control: GET /ctl?mode=ok|stall|dead|segerr   (state printed on every change)
  ok      playlist advances with the clock
  stall   playlist freezes at its current window (no new segments)
  dead    every request answers 404
  segerr  playlist advances, segment requests answer 500
"""
import http.server, os, sys, time, urllib.parse

ROOT = os.environ.get("LIVE_HLS_SEGMENTS") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "seg")
SEG = 2.0
WINDOW = 5
TOTAL = len([f for f in os.listdir(ROOT) if f.endswith(".ts")])
state = {"mode": "ok", "start": time.time(), "frozen": None}

def live_seq():
    if state["mode"] == "stall" and state["frozen"] is not None:
        return state["frozen"]
    return int((time.time() - state["start"]) / SEG)

class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, fmt, *a):
        sys.stderr.write("%s [%s] %s\n" % (time.strftime("%H:%M:%S"), state["mode"], fmt % a))
    def send(self, code, body=b"", ctype="text/plain"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)
    def do_HEAD(self): self.do_GET()
    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == "/ctl":
            mode = urllib.parse.parse_qs(u.query).get("mode", ["ok"])[0]
            if mode == "stall":
                state["frozen"] = live_seq()
            elif mode == "ok" and state["mode"] == "stall" and state["frozen"] is not None:
                # resume where the clock says; the gap is what a late playlist looks like
                state["frozen"] = None
            state["mode"] = mode
            return self.send(200, ("mode=%s seq=%d\n" % (mode, live_seq())).encode())
        if state["mode"] == "dead":
            return self.send(404, b"gone\n")
        if u.path == "/live.m3u8":
            seq = live_seq()
            first = max(0, seq - WINDOW + 1)
            lines = ["#EXTM3U", "#EXT-X-VERSION:3", "#EXT-X-TARGETDURATION:2",
                     "#EXT-X-MEDIA-SEQUENCE:%d" % first]
            for i in range(first, seq + 1):
                lines += ["#EXTINF:2.000,", "s%04d.ts" % (i % TOTAL)]
            return self.send(200, ("\n".join(lines) + "\n").encode(), "application/vnd.apple.mpegurl")
        if u.path == "/vod.m3u8":
            lines = ["#EXTM3U", "#EXT-X-VERSION:3", "#EXT-X-TARGETDURATION:2",
                     "#EXT-X-MEDIA-SEQUENCE:0", "#EXT-X-PLAYLIST-TYPE:VOD"]
            for i in range(15):
                lines += ["#EXTINF:2.000,", "s%04d.ts" % i]
            lines.append("#EXT-X-ENDLIST")
            return self.send(200, ("\n".join(lines) + "\n").encode(), "application/vnd.apple.mpegurl")
        name = os.path.basename(u.path)
        path = os.path.join(ROOT, name)
        if name.endswith(".ts") and os.path.isfile(path):
            if state["mode"] == "segerr":
                return self.send(500, b"segment error\n")
            with open(path, "rb") as f:
                return self.send(200, f.read(), "video/mp2t")
        self.send(404, b"not found\n")

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    print("live HLS fixture on :%d, %d segments" % (port, TOTAL), flush=True)
    http.server.ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()
