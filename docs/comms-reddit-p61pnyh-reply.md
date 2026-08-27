# Reddit draft — reply to u/Powerful_Curiosity (`p61pnyh`)

Covers **DOC-5** (where does feedback go / is there a Discord) and **BUG-72** (Continue Watching and
Up Next disagree with the other Nuvio platforms after switching Trakt → Simkl). One comment, both rows.

Parent: <https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p61pnyh/>

**Status: DRAFT — not posted.**

---

## The draft

> Thank you, and welcome.
>
> No Discord. This thread is the place: I read every comment here, and it's where the beta gets
> announced. If something comes with a crash log, a screenshot or a repro worth attaching, GitHub
> issues are the better home for it: <https://github.com/youngchris29-art/NuvioTV/issues>. Those
> don't scroll away the way comments do.
>
> On Continue Watching: your Trakt → Simkl hunch is very likely right, and there's a good chance
> it's one setting.
>
> The Apple TV picks its watch-progress source **separately from your other devices**. It's in
> Settings > Content Sources > Library & Watch Progress, and there are two of them there: Library
> Source and Watch Progress Source. Both default to Trakt. Switching to Simkl on your phone or on
> the web does not carry over to the TV, because that preference is stored per platform. That's a
> gap on my side rather than a deliberate choice, and it's worth fixing. Trakt and Simkl sign-ins
> are per-device too, so Simkl also needs connecting in Settings > Account & Services on the Apple
> TV itself.
>
> So the first thing worth trying, all on the Apple TV: check that Simkl shows as connected under
> Account & Services, then set Library Source and Watch Progress Source to Simkl. Changing that
> setting re-pulls straight away, so you shouldn't need to sign out of anything.
>
> If both are already on Simkl and it still disagrees, could you tell me:
>
> * which option is selected for each of those two (a photo of that pane is ideal), and
> * one or two specific titles that are wrong: on your phone but missing on the TV, or sitting at
>   the wrong episode.
>
> One thing that isn't a bug, so you're not chasing it: the TV doesn't have mobile's Up Next row.
> Home has Continue Watching, and then Upcoming Episodes, which is an air-date calendar for shows
> in your library rather than your next unwatched episode. The TV also shows fewer Continue
> Watching items than mobile does, so a long list will legitimately look shorter there. Both of
> those are on my list to reconcile.

---

## Why the reply says what it says

Grounded in a read of the pinned submodule commit, not inferred from the report.

**There is a Watch Progress Source setting, and it defaults to Trakt.**
`WatchProgressSource = { TRAKT, SIMKL, NUVIO_SYNC }` with `DEFAULT_WATCH_PROGRESS_SOURCE = TRAKT`
(`shared/…/features/tracking/TrackingSources.kt:13-31`). Continue Watching on tvOS is
`WatchProgressRepository.continueWatching()` (`HomeViewModel.swift:35,130-136`), which forks on that
setting in `currentEntries()` (`WatchProgressRepository.kt:1555-1570`). The tvOS surface is
`ContentSourcesSettingsPane.swift:85,102-133`.

**Connecting Simkl alone changes nothing** — the requested source stays Trakt until the user changes
the setting. And there are *two* independent settings (Library Source, Watch Progress Source), so
having one on Simkl and the other on Trakt is a reachable, confusing state.

**The setting cannot travel from phone/web to the TV.** `watchProgressSource` rides in the Trakt
settings payload (`TraktSettingsRepository.kt:59-61,100-106`), synced inside the **platform-namespaced**
profile-settings blob (`ProfileSettingsSync.kt:112-118,164-172`). tvOS reads/writes namespace `tvos`;
phone and web write `mobile` (`SyncPlatform.kt:17,31-43`). So a source change made anywhere else never
reaches the TV. This is the same namespacing gap DOC-2 already documents for theme and poster style —
it now has a second, more consequential victim, and that is worth raising as its own fix.

**Provider sign-ins are device-local too.** `ProviderCredentialSync` covers TMDB, MDBList and debrid
only (`ProviderCredentialSync.kt:8-17,48-53`) — not Trakt/Simkl OAuth. And if the requested provider
isn't authenticated on the device, `effectiveWatchProgressSource()` silently degrades to `NUVIO_SYNC`
(`TrackingSources.kt:44-51`) — which would show Nuvio-cloud progress matching *neither* Trakt nor
Simkl. That is exactly the "doesn't match the other platforms" shape.

**"Up Next" does not exist on tvOS.** Home is Continue Watching (`HomeView.swift:813-821`) plus
**Upcoming Episodes** (`HomeView.swift:826-833`), which is `UpcomingEpisodesRepository` — next *airing*
episodes for shows in the **Library** (a separate source setting), i.e. an air-date calendar. Mobile's
Up Next is next *unwatched* episodes folded into Continue Watching (`composeApp/…/HomeScreen.kt:83,207-291`).
Saying so plainly stops a correct-by-design difference being chased as a defect.

**The rows are built differently even when the source matches.** tvOS takes the default limit of **20**
(`SeriesContinuity.kt:7`, `WatchProgressRules.kt:16,120-122`); mobile passes **300**
(`HomeScreen.kt:251,1099`). tvOS applies none of mobile's days-cap window, dropped-show filtering,
sort-mode preference or next-up dedup (zero references in `iosApp/`). Mobile also *changes its own*
behaviour when Simkl is the source (`HomeScreen.kt:183`), so on Simkl the two clients diverge in
opposite directions. Real divergence, ours to reconcile, independent of this report.

**Stale pull is the weakest explanation, which is why the reply doesn't lead with it.** Both the
profile pick and every foreground return force `refreshActiveSource` (`SyncManager.kt:238-244,383`;
`ProfilesViewModel.swift:65-69`; `ContentView.swift:119-132`), and a connect/disconnect on the TV drives
a coordinator transition that invalidates the cache
(`WatchProgressSourceCoordinator.kt:105-123,240-272`). One caveat kept honestly: nothing calls the
coordinator's `ensureStarted()` at launch, so that auto-transition path is only armed after the first
sync of a session.

## What the answers discriminate

| Their answer | Reading |
|---|---|
| Watch Progress Source = **Trakt**, or Simkl not connected on the TV | Config + the platform-namespacing gap. Not a defect in the rows; the fix is the setting, plus making the tracking source cross-platform. |
| Both = **Simkl**, connected, and re-picking the profile fixes it | Stale pull — the coordinator's unarmed observe job is the first suspect. |
| Both = **Simkl**, connected, and it still disagrees | Row-construction divergence: the 20-item cap, the missing days-cap window, or the absent Up Next. The titles they name will say which. |
| Library Source and Watch Progress Source **disagree with each other** | Strong tell that the row they call "Up Next" is our Upcoming Episodes. |

## Follow-ups this opens on our side, regardless of their answer

1. **Tracking source is `tvos`-namespaced** and so cannot follow a user across devices. Same class as
   DOC-2's theme/poster gap, but this one changes *data*, not looks. Worth its own row.
2. **Continue Watching limit 20 on tvOS vs 300 on mobile**, and the four mobile-only filters tvOS
   never applies. Reconcile deliberately rather than by accident.
3. **`WatchProgressSourceCoordinator.ensureStarted()` is never called at tvOS launch** — it is armed
   only as a side effect of the first `selectSource`/`refreshActiveSource`.
