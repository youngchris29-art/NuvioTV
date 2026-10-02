#!/usr/bin/env python3
"""Convert the beta thread's markdown body to Reddit rich-text JSON (RTJSON).

Why: editing a rich-text post through /api/editusertext with `text=` (markdown)
converts it to markdown mode and the inline screenshots become bare links
(2026-10-01, post 1wtmutc). Sending `richtext_json=` instead keeps them: each
bare `https://preview.redd.it/<id>.png?...` line becomes an {"e":"img","id":<id>}
node, which renders because the id is in the post's media_metadata.

Handles exactly what the thread body uses: paragraphs, **bold**, [text](url)
links, `* ` bullet lists, and the bare preview image lines. Anything else is
passed through as plain text.

    md-to-rtjson.py body.md > body.rtjson
    # then POST thing_id=t3_<id>&richtext_json=<file>&uh=<modhash>&api_type=json
    # to https://old.reddit.com/api/editusertext from the logged-in session.
    # The response is the post object, not {"json":{"errors":[]}}.
"""
import json, re, sys

INL = re.compile(r'\*\*(.+?)\*\*|\[([^\]]+)\]\((https?://[^\s)]+)\)')
IMG = re.compile(r'^https://preview\.redd\.it/([a-z0-9]+)\.png')


def inline(text):
    nodes, pos = [], 0

    def push(t):
        if not t:
            return
        if nodes and nodes[-1].get("e") == "text" and "f" not in nodes[-1]:
            nodes[-1]["t"] += t
        else:
            nodes.append({"e": "text", "t": t})

    for m in INL.finditer(text):
        push(text[pos:m.start()])
        if m.group(1) is not None:
            nodes.append({"e": "text", "t": m.group(1), "f": [[1, 0, len(m.group(1))]]})
        else:
            nodes.append({"e": "link", "u": m.group(3), "t": m.group(2)})
        pos = m.end()
    push(text[pos:])
    return nodes


def convert(body):
    doc, lines, i = [], body.split("\n"), 0
    while i < len(lines):
        ln = lines[i]
        if not ln.strip():
            i += 1
            continue
        m = IMG.match(ln.strip())
        if m:
            doc.append({"e": "img", "id": m.group(1)})
            i += 1
            continue
        if ln.startswith("* "):
            items = []
            while i < len(lines) and lines[i].startswith("* "):
                items.append({"e": "li", "c": [{"e": "par", "c": inline(lines[i][2:].strip())}]})
                i += 1
            doc.append({"e": "list", "o": False, "c": items})
            continue
        para = []
        while i < len(lines) and lines[i].strip() and not lines[i].startswith("* ") and not IMG.match(lines[i].strip()):
            para.append(lines[i].strip())
            i += 1
        doc.append({"e": "par", "c": inline(" ".join(para))})
    return {"document": doc}


if __name__ == "__main__":
    src = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    json.dump(convert(src), sys.stdout)
