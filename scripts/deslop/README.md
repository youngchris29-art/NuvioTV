# deslop: copy linter (vendored from SlopMonster)

Stdlib-only Python copy of `tools/deslop.py` from
https://github.com/ItsssssJack/SlopMonster (MIT, see LICENSE), vendored so
cloud sessions without the `~/.claude/skills/slopmonster` skill can still run
the gate described in CLAUDE.md ("Copy rule").

    python3 scripts/deslop/deslop.py docs/comms-foo.md     # markdown file
    python3 scripts/deslop/deslop.py --text "paste a draft"
    python3 scripts/deslop/test_deslop.py                   # after touching a regex

Exits 1 below 5/5. Re-sync from the skill folder when the upstream tool changes.
