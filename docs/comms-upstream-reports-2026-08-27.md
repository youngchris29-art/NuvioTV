# Upstream issue drafts — NuvioMedia/NuvioMobile (2026-08-27)

Three findings from the tvOS fork's 2026-08-26 port batch, drafted as GitHub issues for
`NuvioMedia/NuvioMobile`. **Status: DRAFTS — nothing posted.** Christian reviews; post only
what he approves (or he posts them himself). Written against upstream `cmp-rewrite` @ `582ae863`.

---

## Draft 1 — Simkl list mutations can never repair a pre-fix misclassified anime entry

**Title:** Simkl list-mutation media-type precedence prevents repairing entries misclassified before #5003d298

Commit `5003d298` ("respect anime type when adding titles to Simkl library") resolves the media
type from the response's `anime_type`, but `withListMutations` in `SimklMutationReconciliation.kt`
applies it with existing-first precedence:

```kotlin
val mediaType = existing?.mediaType
    ?: mutation.resolvedMediaType
    ?: mutation.request.kind.toSimklMediaType()
```

Any entry a *pre-fix* mutation stored as `SHOWS`/`MOVIES` keeps that wrong type forever: every
later list add/move for the same title finds `existing`, so the server's authoritative
classification is never consulted. Users who added anime to a list before the fix stay
misprojected until they remove and re-add the title.

The history path already prefers the mutation's resolved type (`withResolvedHistoryStatus`:
`mutation.mediaType ?: existing.mediaType`), so the two reconciliation paths currently disagree
on who wins.

Suggested fix — mirror the history path's precedence in `withListMutations`:

```kotlin
val mediaType = mutation.resolvedMediaType
    ?: existing?.mediaType
    ?: mutation.request.kind.toSimklMediaType()
```

Our tvOS fork ships this (with a regression test covering the repair: seed an entry via a
`type: "show"` response, then apply a `type: "anime"` + `anime_type` response for the same ids,
and assert the entry flips to `ANIME`).

## Draft 2 — Catalog descriptor signature lacks collection boundaries, so distinct manifests can collide

**Title:** `CatalogDescriptorSignature` (#191be42a) hashes adjacent collections without boundaries — distinct manifests can produce identical signatures

Commit `191be42a` replaced the `'|'`-delimited catalog-descriptor signature with the FNV-1a
`CatalogDescriptorSignature` — fixing the delimiter-collision problem — but the new builder
flattens adjacent string collections with no size/boundary marker:

```kotlin
manifest.types.forEach(signature::add)
manifest.idPrefixes.forEach(signature::add)
```

Individual strings are length-prefixed, but the boundary *between* collections is not encoded, so
`types = ["movie"], idPrefixes = ["tt"]` hashes identically to
`types = ["movie", "tt"], idPrefixes = []`. The same applies to each resource's
`types`/`idPrefixes` and to `extra.options`. If a refreshed manifest moves between two such
shapes, the signature (and the cache key derived from it) doesn't change, and the stale catalog
definition is kept.

Suggested fix — size-prefix each flattened collection:

```kotlin
signature.add(manifest.types.size)
manifest.types.forEach(signature::add)
signature.add(manifest.idPrefixes.size)
manifest.idPrefixes.forEach(signature::add)
// …same for resources[i].types / resources[i].idPrefixes / extra.options
```

Our tvOS fork ships this hardening on top of the ported hash.

## Draft 3 — Catalog dedup guard strands `isLoading` when a fetch is cancelled

**Title:** `CatalogRepository` request-reuse guard can wedge on a cancelled fetch's stranded `isLoading`

Commit `96fb98c4` changed the dedup guard to
`!force && activeRequest == request && (items.isNotEmpty() || isLoading)` to preserve scroll
position when returning from details. The `isLoading` half trusts that a previous fetch always
completes and clears the flag — but if the fetch's coroutine is cancelled without the state being
reset (screen teardown racing an in-flight load), `isLoading` stays `true` with no active job,
and the guard then short-circuits every subsequent refresh of that request: the catalog shows a
spinner (or stale emptiness) until a `force` refresh or a different request arrives.

Our tvOS fork hit this via its `detach()` teardown path and hardened the guard to require a
live job, plus a heal branch that clears the stranded flag on re-entry:

```kotlin
val fetchStillRunning = activeJob?.isActive == true && _uiState.value.isLoading
if (!force && activeRequest == request &&
    (_uiState.value.items.isNotEmpty() || fetchStillRunning)) { … }
// else: if isLoading is set with no active job, clear it before refetching
```

Sharing in case the same cancellation window is reachable in the Compose apps (config change /
fast back-navigation during an initial catalog load would be the shape to probe).

---

**Posting notes (for whoever posts):** one issue each, titles as given; body verbatim minus this
header section; no fork branding beyond "our tvOS fork" as written; link the relevant upstream
commits by SHA (GitHub auto-links within the repo).
