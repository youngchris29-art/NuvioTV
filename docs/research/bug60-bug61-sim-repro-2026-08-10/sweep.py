#!/usr/bin/env python3
"""BUG-60 / BUG-61 repro sweep: for each poster size, walk DOWN the Home rows in
pinned-hero mode and record the title slide the app itself reports.

Geometry from Theme.swift, so the pass/fail line is not a judgement call:
  shelf top -> title top      = heroPinnedRowTitleInset      48 pt
  shelf top -> artwork top    = Spacing.lg 24 + reach 72     = 96 pt
  title height (sectionTitle)                                ~40 pt
  => static clearance title-bottom -> artwork-top            =  8 pt
A slide greater than 8 pt therefore puts the title ON the artwork; the clamp
(heroPinnedRowTitleMaxSlide) allows up to 72, i.e. up to 64 pt of overlap.
"""
import simkit as sk
import sys, time, re, os

OVERLAP_FREE = 8.0      # pt of slide the static band can absorb
CLAMP = 72.0

SIZES = [("small", 105), ("medium", 126), ("large", 154)]


def settle(log, row_filter=None, seconds=1.6):
    time.sleep(seconds)


def last_slides(logname):
    """Latest slide/margin per row key, in log order."""
    out = {}
    pat = re.compile(r"title row=(\S+) margin=(-?\d+) slide=(-?\d+) net=(-?\d+)")
    for line in open(os.path.join(sk.S, logname), errors="ignore"):
        m = pat.search(line)
        if m:
            out[m.group(1)] = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
    return out


def all_slides(logname):
    pat = re.compile(r"title row=(\S+) margin=(-?\d+) slide=(-?\d+) net=(-?\d+)")
    rows = []
    for line in open(os.path.join(sk.S, logname), errors="ignore"):
        m = pat.search(line)
        if m:
            rows.append((m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4))))
    return rows


def run(label, dp, downs=9):
    print("\n=== poster size %s (%d dp -> %.0f pt wide, %.0f pt tall art) ==="
          % (label.upper(), dp, dp * 220 / 126, dp * 220 / 126 * 1.5))
    sk.set_poster_width(dp)
    logname = "sweep_%s.log" % label
    sk.relaunch(logname)
    time.sleep(14)
    sk.focus_sim()
    sk.press("select", 1, pause=9)          # profile picker -> Home
    time.sleep(4)
    sk.press("down", 1, pause=1.6)          # tab bar -> first row
    for i in range(downs):
        sk.press("down", 1, pause=1.5)
        if i in (2, 4, 6):
            sk.shot("b60_%s_down%d" % (label, i))
    time.sleep(1.5)
    sk.shot("b60_%s_final" % label)

    rows = all_slides(logname)
    if not rows:
        print("  no probe output"); return
    per = {}
    for key, margin, slide, net in rows:
        cur = per.get(key, (0, 0))
        per[key] = (max(cur[0], slide), min(cur[1], net))
    worst = sorted(per.items(), key=lambda kv: -kv[1][0])[:6]
    maxslide = max(s for _, m, s, n in rows)
    minnet = min(n for _, m, s, n in rows)
    over = [k for k, (s, n) in per.items() if s > OVERLAP_FREE]
    print("  probe samples: %d   rows seen: %d" % (len(rows), len(per)))
    print("  MAX slide observed: %d pt   (overlap-free budget %.0f pt, clamp %.0f pt)"
          % (maxslide, OVERLAP_FREE, CLAMP))
    print("  MIN net observed  : %d pt   (negative = title clipped even after sliding)" % minnet)
    print("  rows whose title rode ONTO its own artwork (slide > %.0f): %d of %d"
          % (OVERLAP_FREE, len(over), len(per)))
    if maxslide > OVERLAP_FREE:
        print("  -> worst overlap onto artwork: %.0f pt" % (maxslide - OVERLAP_FREE))
    print("  worst rows (max slide, min net):")
    for k, (s, n) in worst:
        print("     slide=%-3d net=%-4d %s" % (s, n, k[-58:]))
    return dict(label=label, dp=dp, maxslide=maxslide, minnet=minnet,
                overlapping=len(over), rows=len(per))


if __name__ == "__main__":
    which = sys.argv[1:] or [s[0] for s in SIZES]
    results = []
    for label, dp in SIZES:
        if label in which:
            r = run(label, dp)
            if r:
                results.append(r)
    if len(results) > 1:
        print("\n=== SUMMARY ===")
        print(" size      dp   max slide   overlap onto art   rows overlapping")
        for r in results:
            ov = max(0, r["maxslide"] - OVERLAP_FREE)
            print("  %-7s %4d   %6d pt   %10.0f pt        %d/%d"
                  % (r["label"], r["dp"], r["maxslide"], ov, r["overlapping"], r["rows"]))
