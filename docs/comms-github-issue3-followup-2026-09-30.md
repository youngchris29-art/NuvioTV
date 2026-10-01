# GitHub issue #3 FOLLOW-UP draft (2026-09-30 night) — NOT POSTED

Follow-up to the first reply posted from Christian's account on 2026-09-29 17:13Z (by the cloud sweep session; it acknowledged BUG-114, asked for the PR against `NuvioMobile`/`tvos-shared-extraction` and whether Menu recovers the stuck state). `dotjarden` has not answered. This says the fix landed in rc13/rc14, where it differs from their patch, how to verify before beta.18, that the PR is optional now, and re-asks the Menu question. Two-draft judge workflow, lint 5/5, 159 words. Supersedes `docs/comms-github-issue3-reply-2026-09-15.md`.

---
The fix landed in rc13 (build 130, 2026-09-30) and is in rc14 (build 131). It comes from the other side than your patch: when the focus engine can't resolve an Up press or swipe from the hero action, the shelf scrolls to home_top and the native bar is reachable again; a focus change on its own still never scrolls. I confirmed it on an Apple TV 4K on 09-30 with your three-Down repro.

The rc builds are tester builds and aren't on the Releases page; beta.17 is still the latest public release. beta.18 is next and will carry this. If you want to check it before then, say so here and I'll attach an rc IPA to the issue.

The PR is optional now. It's still welcome if it adds something the input-triggered fix doesn't, but this symptom no longer needs it.

The Menu question is still open: does a Menu press recover the stuck state on your build?
