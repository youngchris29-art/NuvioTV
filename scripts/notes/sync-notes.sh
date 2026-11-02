#!/bin/bash
# Mirror docs/ (the Obsidian vault) to a PRIVATE GitHub repo so cloud sessions can read it.
#
#   scripts/notes/sync-notes.sh init     one-time: create the git dir, first commit, push
#   scripts/notes/sync-notes.sh [sync]   commit local changes, pull cloud changes, push
#   scripts/notes/sync-notes.sh status   what would be committed
#
# No .git is ever created inside docs/: the outer NuvioTV repo tracks a few files there, and a
# nested repo would break those. The git dir lives outside the checkout (dotfiles-style
# --git-dir/--work-tree), so Obsidian and the outer repo see nothing new.
#
# Not mirrored: the files the outer repo tracks (already on GitHub, public), Obsidian's
# per-device state, and media/build outputs (GitHub refuses files over 100 MB).
#
# Config (optional): ~/.config/nuvio-notes/config.env
#   NOTES_GITDIR=~/Claude/Projects/nuvio-notes.git
#   NOTES_REMOTE=https://github.com/youngchris29-art/nuvio-notes.git   (create it PRIVATE first)
#
#   exit 0  synced, or nothing to do
#   exit 1  git failed (usually a rebase conflict: resolve with `sync-notes.sh git status`)
#   exit 2  not initialised, or the remote is not private
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$ROOT/docs"
CONFIG="$HOME/.config/nuvio-notes/config.env"
[ -f "$CONFIG" ] && . "$CONFIG"
NOTES_GITDIR="${NOTES_GITDIR:-$HOME/Claude/Projects/nuvio-notes.git}"
NOTES_REMOTE="${NOTES_REMOTE:-https://github.com/youngchris29-art/nuvio-notes.git}"
NOTES_GITDIR="${NOTES_GITDIR/#\~/$HOME}"

g() { git --git-dir="$NOTES_GITDIR" --work-tree="$WORK" "$@"; }

write_exclude() {
  cat > "$NOTES_GITDIR/info/exclude" <<'EXCL'
# Tracked (publicly) by the outer NuvioTV repo; keep one home for each.
/status.md
/upstream-check-latest.md
/nuvio-cloud-api-reference.md
/tvos-port-plan.md
/device-rig-2026-10-15.md
/ios-release-watch.md
/design/
# Obsidian per-device state
/.obsidian/workspace*.json
/.obsidian/cache
/.trash/
.DS_Store
# Media and build outputs
*.mov
*.mp4
*.m4v
*.mkv
*.ts
*.zip
*.ipa
*.xcresult/
*.trace/
EXCL
}

refuse_public_remote() {
  # An unauthenticated API call sees only public repos: a 200 means anyone can read it.
  local slug code
  slug="$(printf '%s' "$NOTES_REMOTE" | sed -E 's#(\.git)?$##; s#^.*github\.com[:/]##')"
  code="$(curl -s -o /dev/null -w '%{http_code}' "https://api.github.com/repos/$slug" || true)"
  if [ "$code" = "200" ]; then
    echo "refusing: $slug is PUBLIC. Make it private first (Settings > General > Danger Zone)." >&2
    exit 2
  fi
}

case "${1:-sync}" in
  init)
    if [ -d "$NOTES_GITDIR" ]; then echo "already initialised: $NOTES_GITDIR"; exit 0; fi
    refuse_public_remote
    git init -q --bare "$NOTES_GITDIR"
    git --git-dir="$NOTES_GITDIR" config core.bare false
    git --git-dir="$NOTES_GITDIR" config core.worktree "$WORK"
    git --git-dir="$NOTES_GITDIR" config status.showUntrackedFiles normal
    write_exclude
    g remote add origin "$NOTES_REMOTE"
    g add -A
    big="$(g diff --cached --name-only -z | xargs -0 -I{} find "$WORK/{}" -size +50M 2>/dev/null || true)"
    if [ -n "$big" ]; then echo "files over 50 MB, add them to $NOTES_GITDIR/info/exclude first:"; echo "$big"; exit 1; fi
    g commit -q -m "notes: first import of docs/"
    g branch -M main
    g push -u origin main
    echo "initialised: $NOTES_GITDIR -> $NOTES_REMOTE"
    ;;
  sync)
    [ -d "$NOTES_GITDIR" ] || { echo "not initialised: run $0 init" >&2; exit 2; }
    refuse_public_remote
    write_exclude
    g add -A
    g diff --cached --quiet || g commit -q -m "notes: sync $(date '+%Y-%m-%d %H:%M')"
    g pull -q --rebase --autostash origin main || { echo "pull failed: resolve with $0 git status" >&2; exit 1; }
    g push -q origin main
    ;;
  status)
    g status --short
    ;;
  git)
    shift; g "$@"
    ;;
  *)
    sed -n '2,9p' "$0"; exit 2
    ;;
esac
