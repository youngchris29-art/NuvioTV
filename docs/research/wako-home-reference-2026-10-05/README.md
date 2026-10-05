# Wako Android TV Home, reference frames (2026-10-05)

Source: Steven's rc2 verdict DM (2026-10-05) linked r/wako post `1wxftwi`, "wako 12.1.22 on Android TV, a quick tour" by u/bj4fr (video `v.redd.it/f6vitrohdgth1`, 69.5 s, 1904x1080, 30 fps). The video itself is not kept in the repo.

What the Home does (read from the frames here):

- Every row: one large landscape card pinned at the left, portrait posters to its right, meta line + synopsis + cast under the card. Unfocused rows show the same shape for their first item.
- Right press: focus never moves on screen. The next poster slides left into the big slot while the big card cross-fades to that title's backdrop; the rest of the row shifts one poster left; the text under the card swaps at the same time (`row-mid-slide-7.7s.png` catches the poster half-way).
- The trailer plays inside that fixed big card (play glyph on the Up Next card).
- Up/Down: one row per page, the focused row sits at the top, the next row's heading peeks underneath.

Relation to `docs/home-stage-strip-plan-2026-10-03.md`: the vertical scheme matches H1/H7. The difference is horizontal: Wako slides the row under a fixed slot; Stage lets focus run along the strip and swaps the stage after a rest. Steven's "synopsis below the tile or above it" option = Wako's text under the card vs the plan's text in the stage.
