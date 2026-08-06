# Upstream port check — 2026-07-31 (scheduled)

## Result: no action items today

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) has **not moved** since the 2026-07-29/07-30 checks — tip is still `979d5680d4a1a755a3e833332c36e5cb3b4d3f71` "Merge branch 'library-delta' into cmp-rewrite". All items from that merge (device session registration, library incremental delta sync, auth error sanitization) were already ported and confirmed landed in the 07-30 check — nothing new to diff or port.

Fork's outer repo HEAD is now `71bea440` (docs/tracker commits — beta.8 announcement); submodule pinned at `5aa7f727` (`tvos-v0.3.0-beta.7-11-g5aa7f727`). All commits since the last upstream port (`731353e`) are fork-only UI/UX work (hero v3, trailer morph, CTA button, Now-column batch, mpv screensaver fix, HIG revamp) — none upstream-derived, nothing to reconcile.

## Watch item (still not actionable): `simkl` feature branch

`upstream/simkl` tip is **unchanged** at `e4911b7742c0` ("fix(simkl): preserve posters during library updates") — same commit flagged in the 07-30 check. This means the branch has gone quiet for about a day, which is the first sign of the "goes quiet for several days" revisit trigger from the prior plan, but one day isn't enough yet to treat it as stabilizing. Still **not merged** into `cmp-rewrite` (`git merge-base upstream/simkl upstream/cmp-rewrite` = `979d5680`, same as cmp-rewrite's tip — confirms zero overlap since the last merge).

No change to the prior assessment: full Simkl tracking-provider integration (anime tracking, PKCE OAuth, scrobble sync) on a new provider-neutral tracking abstraction that also rewrites the Trakt integration tvOS already ported. 101 files, ~9.7k line diff vs. merge-base — too large/unstable to port piecemeal. See `docs/upstream-port-plan-2026-07-30.md` for full breakdown.

**Revisit trigger (unchanged):** `simkl` merges into `cmp-rewrite`, OR the branch goes quiet for several more days (currently at ~1 day and counting).

## Other upstream branches — no change

- `upstream/copilot/refactor-project-structure` — tip unchanged (`cbc9fc4f`, dated March 2026), no common merge-base with `cmp-rewrite` found (diverged history) — treating as stale/abandoned unless it resurfaces with new commits or actually merges.

## For Claude Code (this session)

Nothing to execute this cycle — no gap between upstream `cmp-rewrite` and the tvOS fork. Next scheduled check should just re-verify `cmp-rewrite`'s tip and re-check `simkl`'s quiet streak (5+ days quiet, or a merge into `cmp-rewrite`, is what would make it actionable).
