#!/usr/bin/env python3
"""Stage a HyperFrames release-video project into build/<project>/ for lint and render.

Usage:
    python3 build.py beta19           # beta19/ -> build/beta19/ (fonts + screenshots staged)
    python3 build.py beta5            # beta5/template.html -> build/beta5/index.html (fonts inlined)
    python3 build.py beta19 -o /tmp/x # custom output dir

Two project shapes are supported:

* Multi-file (beta19 onward): `index.html` mounts scenes from `compositions/`,
  music and the brand mark live in `assets/`. The project dir is copied as is,
  then the app's JetBrains Sans .ttf files are copied to `assets/fonts/`, every
  `assets/screens/<name>` the HTML references is copied from
  `design/screenshots/<name>`, and every `assets/brand/<name>` from `design/`.
  Nothing heavy is duplicated in git: only the sources are committed.

* Single-file (beta5): `template.html` with `__FONT_REGULAR__` /
  `__FONT_SEMIBOLD__` / `__FONT_BOLD__` placeholders, replaced by base64 fonts
  and written to `build/<project>/index.html`.

The output goes to a separate build/ dir (gitignored) because the HyperFrames
linter treats every root-level HTML with data-composition-id as an entry point —
template and built file in one dir would count as duplicate roots.

The fonts are read from the NuvioMobile submodule; set NUVIO_FONT_DIR to use
another directory holding the same three .ttf files (e.g. a sparse clone).
"""
import argparse
import base64
import os
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
FONT_DIR = pathlib.Path(
    os.environ.get("NUVIO_FONT_DIR", str(REPO / "NuvioMobile/composeApp/src/commonMain/composeResources/font"))
)
FONT_FILES = ["jetbrains_sans_regular.ttf", "jetbrains_sans_semibold.ttf", "jetbrains_sans_bold.ttf"]
FONT_PLACEHOLDERS = {
    "__FONT_REGULAR__": "jetbrains_sans_regular.ttf",
    "__FONT_SEMIBOLD__": "jetbrains_sans_semibold.ttf",
    "__FONT_BOLD__": "jetbrains_sans_bold.ttf",
}
SCREENSHOT_DIR = REPO / "design/screenshots"
BRAND_DIR = REPO / "design"
ASSET_REF = re.compile(r"assets/(screens|brand|fonts)/([\w.-]+)")


def font_path(fname: str) -> pathlib.Path:
    p = FONT_DIR / fname
    if not p.exists():
        sys.exit(f"font not found: {p} (set NUVIO_FONT_DIR or init the NuvioMobile submodule)")
    return p


def build_single_file(project: pathlib.Path, out_dir: pathlib.Path) -> None:
    html = (project / "template.html").read_text()
    for placeholder, fname in FONT_PLACEHOLDERS.items():
        if placeholder in html:
            html = html.replace(placeholder, base64.b64encode(font_path(fname).read_bytes()).decode())
    leftover = [p for p in FONT_PLACEHOLDERS if p in html]
    if leftover:
        sys.exit(f"unreplaced placeholders: {leftover}")
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "index.html"
    out.write_text(html)
    print(f"wrote {out} ({out.stat().st_size:,} bytes)")


def build_multi_file(project: pathlib.Path, out_dir: pathlib.Path) -> None:
    if out_dir.exists():
        shutil.rmtree(out_dir)
    shutil.copytree(project, out_dir, ignore=shutil.ignore_patterns("*.py", "__pycache__", ".DS_Store"))

    html_files = list(out_dir.glob("*.html")) + list((out_dir / "compositions").glob("*.html"))
    refs = set()
    for f in html_files:
        refs.update(ASSET_REF.findall(f.read_text()))

    copied = []
    for kind, name in sorted(refs):
        dest = out_dir / "assets" / kind / name
        if dest.exists():
            continue
        if kind == "fonts":
            src = font_path(name)
        elif kind == "screens":
            src = SCREENSHOT_DIR / name
        else:
            src = BRAND_DIR / name
        if not src.exists():
            sys.exit(f"referenced asset not found: assets/{kind}/{name} -> {src}")
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        copied.append(f"assets/{kind}/{name}")

    print(f"staged {out_dir} ({len(html_files)} html, {len(copied)} assets copied)")
    for c in copied:
        print(f"  + {c}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("project", help="project dir (e.g. beta19)")
    ap.add_argument("-o", "--output", help="output dir (default build/<project>)")
    args = ap.parse_args()

    project = HERE / args.project
    if not project.is_dir():
        sys.exit(f"no such project: {project}")
    out_dir = pathlib.Path(args.output) if args.output else HERE / "build" / args.project

    if (project / "template.html").exists():
        build_single_file(project, out_dir)
    elif (project / "index.html").exists():
        build_multi_file(project, out_dir)
    else:
        sys.exit(f"{project} has neither template.html nor index.html")


if __name__ == "__main__":
    main()
