#!/usr/bin/env python3
"""BUG-66 sim rig — driver + tab-bar-band measurement.

Question this rig answers (trace doc `traces-2026-08-27-bug66-upcoming.md`, Trace B step 1):
does the tvOS 26 system tab bar minimize on scroll in the sim, per surface —
  Search        (positive control: minimizes on the device)
  Home classic  (hero_nuvio_style=false, heroEnabled=true — the in-house default)
  Home pinned   (hero_nuvio_style=true — the reporter's Nuvio-Style Hero config, H1)

Two independent oracles, both captured per pass:
  1. SCREENSHOT SCAN of the tab-bar band (memory rule: never logs alone). The sim
     renders exactly 2 px per pt (3840x2160 for 1920x1080), so crops are exact.
  2. The app's own `[HomeScrollProbe] <mode> y=.. inset=..` NSLog lines from
     `simctl launch --console-pty` (Home surfaces only). `inset` is the H1 metric:
     157 = the rows scroll view sits under the bar's band, 0 = it does not.

Known hazards designed around (memory):
  - osascript input can silently die (bug75 session) -> every pass self-checks that
    a Down press changed pixels, and FAILS LOUDLY instead of reporting a vacuous verdict.
  - the sim never reproduced BUG-30's clipped-bar device state -> the Search control
    decides whether the sim can show scroll-minimize AT ALL; if the control never
    minimizes, Home results are reported as "rig cannot decide minimize visually"
    and only the inset oracle stands.
  - sips crop pitfalls -> ffmpeg crop only, and crops are saved for visual Read.
"""
import subprocess, os, time, json, sys

UDID = "FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E"
BUNDLE = "com.nuvio.media.NuvioTV"
RIG = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(RIG, "out")
FFMPEG = "/opt/homebrew/bin/ffmpeg"
FFPROBE = "/opt/homebrew/bin/ffprobe"

KEY = {"up": 126, "down": 125, "left": 123, "right": 124, "select": 36, "menu": 53}
PX_PER_PT = 2

# Tab-bar band: visible bar buttons rest at minY ~ +62pt (AX measurements, memory);
# band 0..160 pt covers the whole floating bar incl. its glass pill.
BAND_PT = (0, 160)


def sh(*args, check=True, **kw):
    return subprocess.run(list(args), check=check, capture_output=True, **kw)


def focus_sim():
    sh("osascript", "-e", 'tell application "Simulator" to activate')
    time.sleep(1.0)


def press(name, n=1, pause=0.9):
    for _ in range(n):
        sh("osascript", "-e",
           'tell application "System Events" to key code %d' % KEY[name])
        time.sleep(pause)


def shot(name):
    p = os.path.join(OUT, name + ".png")
    sh("xcrun", "simctl", "io", UDID, "screenshot", p)
    return p


def md5(path):
    return sh("md5", "-q", path).stdout.decode().strip()


def crop_band(png, suffix="band"):
    """Crop the tab-bar band (full width) to <name>.<suffix>.png and return its path."""
    out = png.replace(".png", ".%s.png" % suffix)
    y0, y1 = BAND_PT[0] * PX_PER_PT, BAND_PT[1] * PX_PER_PT
    sh(FFMPEG, "-v", "error", "-y", "-i", png,
       "-vf", "crop=3840:%d:0:%d" % (y1 - y0, y0), out)
    return out


def band_metrics(png):
    """(mean luma, bright-pixel fraction >=140) over the tab-bar band."""
    band = crop_band(png)
    raw = sh(FFMPEG, "-v", "error", "-i", band, "-pix_fmt", "gray",
             "-f", "rawvideo", "-").stdout
    n = len(raw)
    bright = sum(1 for b in raw if b >= 140)
    return {"mean": sum(raw) / n, "bright_frac": bright / n, "crop": band}


# ---------------------------------------------------------------- app control
#
# PREFS SEEDING — the hard-won part (memory: "sim-wide prefs mirage"):
# `simctl spawn <udid> defaults write <bundle> ...` writes a SIM-WIDE domain the
# app never reads (verified again building this rig: it read hero_nuvio_style=0
# while the app ran with true). The app's real domain is the plist inside its
# DATA CONTAINER, which also ROTATES on every reinstall — resolve it fresh every
# time, never cache the path. Edit it with plistlib while the app is terminated
# (BUG-60 rig precedent). Every Home pass then verifies the seed took by reading
# the app's OWN probe mode name ("classic"/"pinned-hero"/"pinned-panel") from the
# launch log, so a cfprefsd cache clobber can never produce a silent wrong-mode
# verdict.

def prefs_path():
    d = sh("xcrun", "simctl", "get_app_container", UDID, BUNDLE, "data").stdout.decode().strip()
    return os.path.join(d, "Library", "Preferences", BUNDLE + ".plist")


def prefs_edit(mutate, path=None):
    """mutate(dict) -> None, applied to the app-container prefs plist. App must be
    terminated. Returns the dict after mutation."""
    import plistlib
    p = path or prefs_path()
    with open(p, "rb") as f:
        d = plistlib.load(f)
    mutate(d)
    with open(p, "wb") as f:
        plistlib.dump(d, f)
    return d


def seed_hero_mode(nuvio_style, hero_enabled, path=None):
    """Set hero_nuvio_style (bool, app-wide) and heroEnabled inside every
    catalog_settings_payload_<idx> (profile-scoped JSON) so the seed holds no
    matter which profile the picker's default focus selects."""
    def mutate(d):
        d["hero_nuvio_style"] = bool(nuvio_style)
        d["debug.homeScrollProbe"] = True
        d["debug.tabBarProbe"] = True
        for k in list(d):
            if k.startswith("catalog_settings_payload_"):
                p = json.loads(d[k])
                p["heroEnabled"] = bool(hero_enabled)
                d[k] = json.dumps(p, separators=(",", ":"))
    prefs_edit(mutate, path=path)


def cold_seed(nuvio_style, hero_enabled):
    """seed_hero_mode through a full sim shutdown/boot: cfprefsd's cache dies with
    the sim, so the plist edit cannot be clobbered. ~40s. Needed whenever a pass
    FLIPS the mode (the warm edit only holds when the value already matches what
    cfprefsd last flushed — the run_ab self-check catches it either way)."""
    terminate()
    p = prefs_path()          # resolve while booted — simctl can't while shut down
    sh("xcrun", "simctl", "shutdown", UDID, check=False)
    time.sleep(5)
    seed_hero_mode(nuvio_style, hero_enabled, path=p)
    sh("xcrun", "simctl", "boot", UDID)
    time.sleep(15)
    sh("open", "-a", "Simulator")
    time.sleep(5)


def read_pref(key):
    import plistlib
    with open(prefs_path(), "rb") as f:
        return plistlib.load(f).get(key)


def terminate():
    sh("xcrun", "simctl", "terminate", UDID, BUNDLE, check=False)
    time.sleep(2)


def launch(logname):
    """Launch with a console pty so NSLog probe lines land in OUT/<logname>."""
    log = open(os.path.join(OUT, logname), "wb")
    proc = subprocess.Popen(
        ["xcrun", "simctl", "launch", "--console-pty", UDID, BUNDLE],
        stdout=log, stderr=subprocess.STDOUT)
    return proc


def probe_lines(logname):
    """[(mode, y, inset, residual, is_rest)] parsed from [HomeScrollProbe] lines."""
    import re
    pat = re.compile(r"\[HomeScrollProbe\] (REST )?(\S+) y=(-?\d+) inset=(-?\d+) residual=(-?\d+)")
    out = []
    for line in open(os.path.join(OUT, logname), errors="ignore"):
        m = pat.search(line)
        if m:
            out.append((m.group(2), int(m.group(3)), int(m.group(4)),
                        int(m.group(5)), bool(m.group(1))))
    return out


def assert_input_alive(tag):
    """Press Down and require the screen to change. Two failures = the osascript
    input path is dead (bug75 session class) -> abort loudly, do NOT keep walking."""
    for attempt in range(2):
        a = shot("%s_inputcheck_a" % tag)
        press("down", 1, pause=1.4)
        b = shot("%s_inputcheck_b" % tag)
        if md5(a) != md5(b):
            press("up", 1, pause=1.4)   # undo the probe press
            return True
        time.sleep(1.0)
        focus_sim()
    raise SystemExit(
        "INPUT DEAD: two Down presses changed zero pixels (%s). osascript is not "
        "reaching the app — fall back to the XCUIRemote harness (NuvioTVUITests)." % tag)
