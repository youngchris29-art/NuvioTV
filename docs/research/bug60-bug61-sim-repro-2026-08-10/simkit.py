#!/usr/bin/env python3
"""Sim driver + pixel measurement for the BUG-60 / BUG-61 repro.

The tvOS sim renders 1920x1080 points into a 3840x2160 screenshot, i.e. exactly
2 px per point — so unlike the tester's handheld footage, every measurement here
is exact and absolute positions ARE trustworthy.
"""
import subprocess, os, time, json, plistlib

UDID = "FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E"
BUNDLE = "com.nuvio.media.NuvioTV"
S = "/private/tmp/claude-501/-Users-christianturnbull-Claude-Projects-Nuvio-tvOS/ddbe2c23-7401-4ce9-99ac-0432ec1d1a86/scratchpad"
PREFS = os.path.expanduser(
    "~/Library/Developer/CoreSimulator/Devices/%s/data/Containers/Data/Application/"
    "426EEFCC-FD2B-41B5-93DF-F187FB7F44BE/Library/Preferences/%s.plist" % (UDID, BUNDLE))

KEY = {"up": 126, "down": 125, "left": 123, "right": 124, "select": 36, "menu": 53}
PX_PER_PT = 2.0


def press(name, n=1, pause=0.55):
    for _ in range(n):
        subprocess.run(["osascript", "-e", 'tell application "System Events" to key code %d' % KEY[name]],
                       check=True, capture_output=True)
        time.sleep(pause)


def focus_sim():
    subprocess.run(["osascript", "-e", 'tell application "Simulator" to activate'],
                   check=True, capture_output=True)
    time.sleep(1.0)


def shot(name):
    p = os.path.join(S, name + ".png")
    subprocess.run(["xcrun", "simctl", "io", UDID, "screenshot", p],
                   check=True, capture_output=True)
    return p


def gray(png):
    """PNG -> (w, h, luma bytes) via ffmpeg (no PIL on this box)."""
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0",
                            "-show_entries", "stream=width,height", "-of", "json", png],
                           capture_output=True, check=True).stdout
    st = json.loads(probe)["streams"][0]
    w, h = st["width"], st["height"]
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", png, "-pix_fmt", "gray",
                          "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    assert len(raw) == w * h, (len(raw), w, h)
    return w, h, raw


def col_profile(w, h, raw, x0, x1, y0=0, y1=None):
    """mean luma per row y over the column band [x0,x1)."""
    y1 = y1 or h
    n = x1 - x0
    return {y: sum(raw[y * w + x] for x in range(x0, x1)) / n for y in range(y0, y1)}


def runs(prof, thresh, y0, y1):
    out, cur = [], None
    for y in range(y0, y1):
        if prof.get(y, 0) >= thresh:
            cur = [y, y] if cur is None else [cur[0], y]
        elif cur:
            out.append(tuple(cur)); cur = None
    if cur:
        out.append(tuple(cur))
    return out


def set_poster_width(dp):
    """Rewrite the profile-scoped poster-style payload straight in prefs."""
    d = plistlib.load(open(PREFS, "rb"))
    k = "poster_card_style_payload_2"
    p = json.loads(d[k])
    p["widthDp"] = dp
    p["heightDp"] = (dp * 3) // 2
    d[k] = json.dumps(p, separators=(",", ":"))
    plistlib.dump(d, open(PREFS, "wb"))
    return p


def relaunch(logname):
    subprocess.run(["xcrun", "simctl", "terminate", UDID, BUNDLE], capture_output=True)
    time.sleep(2)
    log = open(os.path.join(S, logname), "wb")
    proc = subprocess.Popen(["xcrun", "simctl", "launch", "--console-pty", UDID, BUNDLE],
                            stdout=log, stderr=subprocess.STDOUT)
    return proc


def probe_lines(logname, kind="title"):
    p = os.path.join(S, logname)
    out = []
    for line in open(p, errors="ignore"):
        if "[HomeScrollProbe] " + kind in line:
            out.append(line.split("[HomeScrollProbe] ")[1].strip())
    return out
