#!/usr/bin/env python3
"""BUG-66 A/B protocol. Usage:
    python3 run_ab.py [pass ...]     # default: all four passes

Passes (each from a fresh launch, profile picked by default-focus Select):
    search        positive control — Search tab, deep scroll (bar recedes on device)
    classic       Home, hero carousel in-scroll (in-house default; nuvio=F, hero=T)
    pinned-hero   Home, Nuvio-Style Hero (the reporter's config; nuvio=T)
    pinned-panel  Home, hero off (the other pinned flavor; nuvio=F, hero=F)

Each pass captures: top / mid / deep / return-to-top screenshots + tab-bar band
crops, band metrics, and (Home passes) the app's [HomeScrollProbe] lines — whose
mode name also SELF-VALIDATES that the seeded hero mode actually took effect.
Artifacts land in out/<pass>_*; summary prints at the end. Verdicts are made by
READING the band crops (house rule: screenshot scan, never metrics/logs alone).
"""
import sys, time, subprocess
import barkit as bk

SEED = {  # pass -> (hero_nuvio_style, heroEnabled), None = leave prefs alone
    "search": None,
    "classic": (False, True),
    "pinned-hero": (True, True),
    "pinned-panel": (False, False),
}
EXPECT_MODE = {"classic": "classic", "pinned-hero": "pinned-hero",
               "pinned-panel": "pinned-panel"}


def view(png):
    subprocess.run([bk.FFMPEG, "-v", "error", "-y", "-i", png,
                    "-vf", "scale=1280:-1", png.replace(".png", "_view.png")])


def snap(tag, stage):
    p = bk.shot("%s_%s" % (tag, stage))
    view(p)
    m = bk.band_metrics(p)
    print("  %-8s band mean=%5.1f bright=%.4f md5=%s"
          % (stage, m["mean"], m["bright_frac"], bk.md5(m["crop"])[:8]))
    return m


def launch_to_home(tag):
    bk.terminate()
    logname = "%s.log" % tag
    bk.launch(logname)
    time.sleep(16)
    bk.focus_sim()
    pre = bk.shot("%s_picker" % tag)
    bk.press("select", 1, pause=9)
    time.sleep(4)
    post = bk.shot("%s_entered" % tag)
    if bk.md5(pre) == bk.md5(post):
        raise SystemExit("PASS %s: Select changed nothing — input dead or picker "
                         "missing. Inspect out/%s_picker.png" % (tag, tag))
    return logname


def walk(tag, downs_mid=3, downs_deep=5):
    """top -> mid -> deep -> walk back up -> return. Screenshots at each station."""
    r = {}
    r["top"] = snap(tag, "top")
    bk.focus_sim()                       # osascript keys get eaten if Simulator
    bk.press("down", downs_mid, pause=1.4)   # loses frontmost between batches
    r["mid"] = snap(tag, "mid")
    bk.focus_sim()
    bk.press("down", downs_deep, pause=1.4)
    time.sleep(1.5)
    r["deep"] = snap(tag, "deep")
    bk.focus_sim()
    bk.press("up", downs_mid + downs_deep + 1, pause=1.4)
    time.sleep(2.0)
    r["return"] = snap(tag, "return")
    return r


def run_home(name):
    tag = name.replace("-", "_")
    nuvio, hero = SEED[name]
    print("== %s (hero_nuvio_style=%s heroEnabled=%s)" % (name, nuvio, hero))
    bk.terminate()
    if "--cold" in sys.argv:
        bk.cold_seed(nuvio, hero)
    else:
        bk.seed_hero_mode(nuvio, hero)
    logname = launch_to_home(tag)
    walk(tag)
    bk.terminate()
    time.sleep(1)
    lines = bk.probe_lines(logname)
    modes = sorted({l[0] for l in lines})
    insets = sorted({l[2] for l in lines})
    ys = [l[1] for l in lines]
    print("  probe: %d lines, modes=%s insets(uniq)=%s y=[%s..%s]"
          % (len(lines), modes, insets[:6],
             min(ys) if ys else "-", max(ys) if ys else "-"))
    exp = EXPECT_MODE[name]
    # A handful of "classic" lines always lead the log: Home renders once with
    # default settings before the profile payload loads. Validate on the DOMINANT
    # mode (and print the split), not on set equality.
    if not lines:
        print("  !! NO PROBE LINES — homeScrollProbe seed did not take; pass invalid")
    else:
        from collections import Counter
        c = Counter(l[0] for l in lines)
        dominant, dn = c.most_common(1)[0]
        if dominant != exp or dn < len(lines) * 0.8:
            print("  !! MODE MISMATCH: expected %s, got %s — cfprefsd likely "
                  "clobbered the seed; rerun this pass with --cold" % (exp, dict(c)))
        else:
            print("  seed verified by app probe: dominant mode=%s (%s)" % (exp, dict(c)))


def run_search():
    tag = "search"
    print("== search (positive control; prefs untouched)")
    logname = launch_to_home(tag)
    bk.press("up", 2, pause=1.2)      # into the tab bar
    bk.press("right", 1, pause=2.5)   # Home -> Search, switches on focus
    time.sleep(3)
    snap(tag, "top")
    bk.press("down", 4, pause=1.3)
    snap(tag, "mid")
    bk.press("down", 5, pause=1.3)
    time.sleep(1.5)
    snap(tag, "deep")
    bk.press("up", 9, pause=1.3)
    time.sleep(2.0)
    snap(tag, "return")
    bk.terminate()


if __name__ == "__main__":
    which = [a for a in sys.argv[1:] if not a.startswith("--")] or ["search", "classic", "pinned-hero", "pinned-panel"]
    for name in which:
        if name == "search":
            run_search()
        else:
            run_home(name)
    # leave the fixture in the reporter's config (its state when this rig was built)
    bk.terminate()
    bk.seed_hero_mode(True, True)
    print("\nfixture prefs restored to nuvio-style (reporter config). "
          "Now READ the out/*_{top,mid,deep,return}.band.png crops before "
          "declaring any verdict.")
