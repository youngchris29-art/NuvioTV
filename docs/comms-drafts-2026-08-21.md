# Comms drafts — 2026-08-21

The eight owed messages from `docs/issue-triage-plan-2026-08-21.md` (§2, §4.2, §7 "Comms owed").
The two GitHub comments were posted 2026-08-21; the six Reddit replies are ready to paste into the
beta thread.

## GitHub (posted)

### 1. Issue #2 — konrepo, "Some video no stream" ✅ posted
<https://github.com/youngchris29-art/NuvioTV/issues/2#issuecomment-5365068641>

> The fix for addon headers shipped in beta.13.5 — the tvOS players now forward `proxyHeaders`
> like mobile does. Could you update and retest? If the personal addon or KhmerTV channels still
> buffer, could you tell me which ones by name — that'll help me separate slow-host buffering
> from the real failures. I see your SundayDrama catalog is offline on their end, so that one we
> can't verify.

### 2. Issue #1 — ozdek, login crash ✅ posted
<https://github.com/youngchris29-art/NuvioTV/issues/1#issuecomment-5365068903>

> Gentle follow-up on the retest ask from yesterday. The preferences overflow that crashed you
> shipped fixed back in beta.10. If it still crashes on beta.13.5, a fresh .ips crash log would
> confirm it's something else. No pressure — if I don't hear back in a week I'll close this as
> fixed, and you can reopen anytime if it comes back.

## Reddit (posted 2026-08-22 as one combined beta.14 comment, `p55f80n` — see `comms-reddit-beta14-comment.md`; #3 dropped as obsolete once the JSON landed by DM)

### 3. BUG-38 — collection covers, alternate delivery channel

> The DM route hit errors on your end twice. Let's try a different channel: could you paste the
> Collections JSON export as a reply here, or drop it via a file link? That'll let me trace
> what's happening with those cover images.

### 4. BUG-58 / BUG-65 — color picker verdict ask

> The white-on-white picker issue shipped fixed in beta.13.5 — settings rows now track their own
> focus state and the swatches have a contrasting ring. Does that look right to you? Once I
> hear, both rows can close.

### 5. BUG-41 — choppy description scroll, re-verdict ask

> Three builds of other work have landed since you reported the choppy scroll. Could you give
> beta.13.5 a quick scroll through that description and let me know if it's still stuttering, or
> if it's smooth now? If it's still choppy I'll instrument it on device to see what's happening.

### 6. BUG-55 — trailers, spinner-vs-nothing question

> TMDB doesn't have any videos for "Nando entre dos mundos" in any language, so not showing a
> trailer is actually correct behavior there. One question: does that title show a loading
> spinner, or a clean "no trailer available" state? Once I know, this row is done.

### 7. BUG-37 — row titles clipped, final repro ask

> I need a photo or screenshot of the clipped state to move forward on this one. Two video
> reviews haven't caught it yet, and I can't reproduce it in-house. If you can grab that shot,
> I'll be able to see what's happening.

*(Per the 2026-08-21 decision: if nothing arrives, BUG-37 downgrades P1 → P3 and parks.)*

### 8. BUG-62 — top menu bar freezing, follow-up

> Following up on the questions from 2026-08-13 — I still need the build number you were on,
> whether the bar got stuck visually or the app stopped responding, and whether it happened
> while you were scrolling back up to Home. That context will help me separate this from the
> tab-bar work that's already in progress.
