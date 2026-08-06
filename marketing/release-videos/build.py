#!/usr/bin/env python3
"""Inject base64 JetBrains Sans fonts into a HyperFrames release-video template.

Usage:
    python3 build.py beta5            # beta5/template.html -> build/beta5/index.html
    python3 build.py beta5 -o out.html

The output goes to a separate build/ dir (gitignored) because the HyperFrames
linter treats every root-level HTML with data-composition-id as an entry point —
template and built file in one dir would count as duplicate roots.

The template references fonts via __FONT_REGULAR__ / __FONT_SEMIBOLD__ /
__FONT_BOLD__ placeholders; the real .ttf files live in the NuvioMobile repo
so the video always uses the app's actual brand font.
"""
import argparse
import base64
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
FONT_DIR = HERE.parent.parent / "NuvioMobile/composeApp/src/commonMain/composeResources/font"
FONTS = {
    "__FONT_REGULAR__": "jetbrains_sans_regular.ttf",
    "__FONT_SEMIBOLD__": "jetbrains_sans_semibold.ttf",
    "__FONT_BOLD__": "jetbrains_sans_bold.ttf",
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("project", help="project dir containing template.html (e.g. beta5)")
    ap.add_argument("-o", "--output", help="output path (default <project>/index.html)")
    args = ap.parse_args()

    project = HERE / args.project
    template = project / "template.html"
    if args.output:
        out = pathlib.Path(args.output)
    else:
        out = HERE / "build" / args.project / "index.html"
        out.parent.mkdir(parents=True, exist_ok=True)

    html = template.read_text()
    for placeholder, fname in FONTS.items():
        if placeholder not in html:
            continue
        font_path = FONT_DIR / fname
        if not font_path.exists():
            sys.exit(f"font not found: {font_path}")
        html = html.replace(placeholder, base64.b64encode(font_path.read_bytes()).decode())

    leftover = [p for p in FONTS if p in html]
    if leftover:
        sys.exit(f"unreplaced placeholders: {leftover}")

    out.write_text(html)
    print(f"wrote {out} ({out.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
