# Reporter communication drafts — beta.11 campaign (2026-08-06)

Status: **DRAFTS — nothing posts without Christian's explicit approval.**
Posting channel notes: BUG-47 goes by Reddit DM (that's where the report arrived); the other two are
thread replies on the beta post. BUG-31 additionally needs Christian to film the counter-video on the
Living Room Apple TV before the reply can carry it.

---

## 1. BUG-47 — reply to u/tiyeuedm (Reddit DM) — REWRITTEN after the 2026-08-06 repro

**Status change: reproduced in-house on tvOS 27.** The "crash" is an app EJECT, not a process
termination: the expanded search grid comes up empty ("No titles here yet"), focus silently falls to
the tab bar, and Back/Menu from there exits the app to the home screen. No crash log exists (the app
is suspended, not killed) — so we do NOT ask for an .ips; we ask for the one confirm that pins the
diagnosis, and we can honestly say the fix is already made.

> Good news — I reproduced this on tvOS 27 and it's fixed for the next beta. Two things you can
> confirm for me to make sure your case matches mine, if you don't mind:
>
> 1. When you expanded the search results, was the page **empty** — a "No titles here yet." message
> instead of a grid of posters?
> 2. After it kicks you to the home screen, if you reopen NuvioTV, does it come back **on that same
> empty page** (rather than starting fresh)?
>
> If yes to both, it's exactly what I found: that expanded page loses your search (so it comes up
> empty), and with nothing on the page to focus, the Back press was reaching the system instead of
> going back — which throws you out of the app. Next beta: Back always works there, and the empty
> page gives you a Go Back button. The deeper fix (making that page actually show your search
> results) is coming in the beta after.
>
> Thanks for reporting it — this also explains why you couldn't just search again: the app was
> resuming into the same dead-end page.

**Why this wording:** the two confirms distinguish our reproduced mechanism from a genuine process
crash on their box (if they answer "no — it restarted fresh", a real termination is back on the
table and THEN we ask for the .ips). Promises match what actually ships in beta.11 (focusable
empty state + pop hardening) vs beta.12 (query threading).

---

## 2. BUG-38 — clarification ask to u/mrStevenx3 (thread reply, on their `p1vylo0` follow-up)

> Quick question on the missing artwork so I fix the right thing — there are three different pieces
> and I want to be sure which you mean:
>
> 1. **The genre/collection tiles** (Action, Animation…) that show a flat colored rectangle — those
> now pull real artwork in the next beta (they'll use the collection's first title as a cover), and
> I'm also adding the collection's **title/logo image** on top when one exists.
> 2. **The service tiles** (Netflix, Prime…) — in your video those *do* show their poster-collage
> backgrounds while at rest. What I think you might mean: **when you focus one, it plays the animated
> logo on a black background**, so the collage disappears while focused. Is that the thing that looks
> like a "missing background" to you? (That's a deliberate animation today — if it reads as broken,
> I can make the collage stay behind the logo, or add a setting to turn the focus animation off.)
> 3. Something else entirely — if so, a timestamp in your video would nail it.
>
> Your videos have been the most useful bug reports this beta has had, by some distance.

**Why this wording:** the video analysis showed the service-tile "missing backgrounds" are almost
certainly the focus-GIF-on-black design behavior, not missing artwork; asking with the three concrete
options avoids a third mis-aimed fix on this row.

---

## 3. BUG-31 — counter-video reply to u/mrStevenx3 (thread reply; VIDEO REQUIRED FIRST)

**Blocker: Christian films a focused poster on the Living Room Apple TV showing the "top only"
depth-effect setting rendering correctly (top band only). Suggested shot list, ~20 seconds:**
- Settings → Appearance: show the depth-effect option set to "Top only" (proves the setting state).
- Home: focus one poster with clean artwork (the same title as their video if possible — Batman was
  their broken example, Cape Fear their working one), hold focus ~3s.
- Move focus to a second poster, hold ~3s.

> Here's the same setting on my Apple TV — recorded just now on the current build: [video]
> Top-only is active in Settings, and on my screen the effect draws only along the top edge on every
> poster I tried, including ones that show the full outline on yours. So we're looking at the same
> setting doing different things on our two devices, which means the interesting question is what
> differs — not the drawing code (I'm not changing it again blind).
> Could you tell me: are you on the White accent theme in that clip, and does the full-outline look
> affect *every* poster for you, or only some (your Batman/Cape Fear split)? The next beta also adds
> a "No Zoom on Focus" option you asked about — curious whether the outline behaves differently with
> that on.

**Why this wording:** the reporter explicitly asked for exactly this video before any further code
change; the questions target the two live hypotheses (settings-sync divergence per the BUG-25/BUG-33
class; poster-geometry dependence).

---

## Posting checklist (after approval)
- [ ] Christian approves draft 1 → send DM to u/tiyeuedm
- [ ] Christian approves draft 2 → reply on the thread
- [ ] Christian films the BUG-31 video → approves draft 3 → reply with video attached
- [ ] Log all three in the tracker's update log (next daily sweep will pick up answers)
