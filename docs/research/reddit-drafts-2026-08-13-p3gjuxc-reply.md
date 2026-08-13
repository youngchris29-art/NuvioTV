# Reply to u/StudioKentin (`p3gjuxc`) — draft

**✅ POSTED 2026-08-13T15:45:29Z** as [`p3h0asv`](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p3h0asv/), a direct reply to `p3gjuxc`, at Christian's explicit instruction ("post it"). Posted through **ego-browser** on `old.reddit.com` from the logged-in youngchris2989 session. **Verified three ways:** the textarea hashed byte-identical to this file's body before submit (sha256 `9c0a81aef8423c40`, 2697 chars), the post-submit DOM showed exactly one new comment with `parent_id = t1_p3gjuxc`, and the comment's own `.json` returned the same sha256 for the stored body. The text below is the as-posted version, unchanged.

**Route snag worth remembering — it nearly posted to the wrong box.** On a comment permalink, old.reddit renders the *comment's own body* inside a `form.usertext`, so `comment.querySelector('form.usertext')` returns that display form (action `editusertext`, no submit button) rather than the reply form. The first submit attempt hit it and did nothing — which was lucky, because the page also carries the **top-level comment box for the whole post** (`form-t3_1v26ebw7ja`), and a looser selector could have posted this reply as a new top-level comment. **Select the reply form by id — `commentreply_<parent_fullname>` — or by walking up from the textarea that actually holds your text.** Verify `parent_id` after posting, not just that a comment appeared.

**Post as** a direct reply to u/StudioKentin's first comment on the beta thread (`p3gjuxc`, 2026-08-13T15:15:57Z)
https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p3gjuxc/

Covers **BUG-62** (top menu bar freezing) and **FEAT-22** (auto-play a specific quality), both filed 2026-08-13.

---

## Grounding — what was verified before writing this

Every claim in the body was checked against the code or git, not against the tracker's own status text.
Two of those checks changed what the reply says.

- **BUG-30 shipped in beta.11. It is not unreleased.** The tracker row still says *unreleased (2026-08-05
  beta.11 batch, `0ad450b6`)* because that status was written four days before the cut. `git merge-base
  --is-ancestor 0ad450b6 f9e4ae56` confirms the reframe is in the released build 107. **This is why the reply
  asks for the build number first and does not name the bug**: on 107 the fix is already in their app and
  their freeze is probably something else; on 106 or older, BUG-30 explains it and is already fixed for them.
  Naming it before knowing the build would set up exactly the "you said it was fixed" problem that damaged
  the mrStevenx3 relationship.
- **There is no preferred-quality setting on tvOS today, and the reporter is right that there is *something*.**
  What exists in the tvOS UI is Stream Badges (quality / HDR / audio-channel chips on stream rows,
  `Screens/Settings/StreamBadgesSection.swift`). `PlaybackSettingsPane.swift` has no quality or resolution
  control at all. **But the primitive already exists in the shared layer**: `DebridSettings.preferredResolutions`
  (an ordered 2160p → 360p ranking, consumed by `DebridStreamPresentation.resolutionRank`) and
  `StreamAutoPlayMode` (MANUAL / FIRST_STREAM / REGEX_MATCH) with `StreamAutoPlaySource`. Neither is exposed
  in any tvOS Settings pane, and `DebridStreamPresentation` is not referenced from Swift at all, so on tvOS
  the ranking never runs. **So FEAT-22 is wiring plus UI, not new infrastructure** — the same shape as the
  upstream cache-control port. The reply says the groundwork exists without promising when.

## Deliberate choices worth checking before posting

- **It asks for the build number before diagnosing anything.** That is the whole point of the first half.
  The temptation is to say "I think I know what that is" — resisted deliberately, per the note above.
- **It does not promise dates.** Consistent with every prior reply.
- **It admits the quality setting does not exist** rather than pointing them at the badges and calling that
  an answer. They said "more", so they have already found the badges.
- **It asks the two design questions now**, because FEAT-22 cannot be built without them and asking later
  costs a whole round trip.
- **It asks for a clip.** The single highest-yield tester behaviour of this beta has been video. Worth
  establishing early with a new reporter, framed as optional so it does not read as a demand.
- **It is short.** This is a first-time reporter with a two-clause comment, not a 16-point review. Matching
  their length is the right register.

## Automod notes

No service brand names, no "torrent", no links beyond the plain text. No backticks and no em dashes in the
body. Composer gotchas as usual: verify the expanded composer before typing, validation lags a few seconds.
If posting through ego-browser on old.reddit.com, use a DOM-level `btn.click()` rather than a synthetic
mouse event, and check the thread JSON before any retry.

---

## Body (as-drafted)

Thank you, and welcome. Both of those are useful, so let me take them one at a time.

**The menu bar freezing.** I want to fix this properly rather than guess, so could you tell me three things?

- **Which build you are on.** Settings, then About, at the bottom. It shows the version and build number.
- **Whether the bar freezes visually or stops responding.** Those are two different bugs for me. Does the bar look stuck or half drawn while the remote still works, or does the remote stop doing anything at all?
- **What you were doing just before it happened.** Especially whether you had scrolled down the Home page and were coming back up.

The reason I ask about the build first is that I have a known bug in this area, and a fix for it went out in the most recent beta. So depending on which build you are on, either you already have that fix and this is something new that I want to chase, or you do not have it yet and it may already be solved for you. I would rather find that out than tell you it is fixed twice.

If it is easy to catch on camera, even a few seconds filmed off the TV would help a lot. Other testers have done that in this thread and it has found things I could not have found on my own. Only if it is convenient though.

**Playback quality options.** Short answer: what you are asking for does not exist yet, and I would like to add it.

Right now the only quality feature is the badges on the stream list, which label the quality rather than choose it. There is no setting that says "always pick 1080p for me". The groundwork for it is already in the app's shared code, including a preferred resolution order and a mode for picking a stream automatically, but none of it is connected to a setting on Apple TV yet. So this is mostly wiring and a settings screen rather than something I would be starting from nothing. I am not going to give you a date.

Two things I need to decide before building it, and I would rather have your opinion than guess:

- **What should happen when your preferred quality is not available?** Drop to the next one down, take the closest one either way, or stop and show you the list?
- **Which do you want more, the best quality or the fastest start?** The highest quality file is often not the one that is ready to play instantly, so an automatic pick has to favour one of them. I could make that a choice too, but I would like to know which one you would set it to.

And one small thing: you said "more" quality options, which makes me think you found something already. If there is a setting you are working from, tell me which one and I will make sure I am building on top of it rather than beside it.

Thanks again for trying it out.
