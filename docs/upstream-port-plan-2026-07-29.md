# Upstream Port Plan — 2026-07-29

**✅ IMPLEMENTED 2026-07-29 (same day).** All three items ported (Item 1 per the 07-27 spec, Items 2+3 below). Gradle build + all 45 `:shared:tvosSimulatorArm64Test` tests green (incl. the 3 ported delta-sync suites and `LibraryRepositoryTest`, relocated from composeApp commonTest since `LibraryLocalState` went `internal`). **Step 0 result:** probed `api.nuvio.tv` with apikey — old `sync_push_library`/`sync_pull_library` still live (403 session-required) AND all four new delta RPCs + `register_current_device` already exist (401 permission-denied for anon = present). Nothing was broken; this landed as ahead-of-deprecation compatibility work. Two deviations from the text below: (1) the Step 2a code block under-transcribed upstream's visibility — upstream marks ALL the state types + `LibraryLocalState` + `LibraryProfileToken` `internal`; the ported file matches upstream byte-for-byte; (2) `runAccountStorageWipe` kept public (upstream has it `internal`) because composeApp's `LocalAccountDataCleaner` calls it cross-module. Device test (sign-in → device registration; library save/remove → delta push) still pending on the Living Room Apple TV.

**Task:** Port upstream changes from `upstream/cmp-rewrite` into this fork's `shared/` module. This document is self-contained — implement it top to bottom. Three items, ordered by priority (biggest/most valuable first).

## Context (read first)

- This repo is a tvOS port of NuvioMobile (Kotlin Multiplatform). The `NuvioMobile/` submodule contains the KMP code; app logic was extracted into `NuvioMobile/shared/src/commonMain` (branch `tvos-shared-extraction`), consumed by a **native SwiftUI tvOS app** — there is no Compose UI on tvOS.
- Anything in upstream's `composeApp/` Compose UI, Android resources, or drawables is **not portable and not needed**. Only changes that map into files under `shared/` (or need a Swift call site) matter.
- Upstream remote: `upstream`, branch `cmp-rewrite`. Previous scheduled check (2026-07-28) had upstream tip at `88d3cbdf` with zero new commits. This check (2026-07-29) found tip moved to `979d5680` — 2 new commits + 1 merge (`d55ed7ae`, `1b05c222`, merge `979d5680`). Both commits touch `composeApp/src/commonMain` business logic (not Compose UI), and both have direct `shared/` counterparts — genuinely relevant to tvOS.
- tvOS's naming conventions differ slightly from upstream's composeApp and must be preserved when porting (don't blindly copy-paste):
  - Toasts: tvOS uses `com.nuvio.app.core.ui.ToastControllerProvider.controller.show(...)`, not upstream's `NuvioToastController.show(...)`.
  - Localized strings: tvOS uses `resourceString(fallback, StringKey.xxx)` from `com.nuvio.app.core.i18n`, not upstream's Compose-resources `getString(Res.string.xxx)` / `StringResource`.
  - Coroutine scopes: tvOS's `LibraryRepository.syncScope` already includes `+ uncaughtCoroutineLogger("LibraryRepository")` — keep that, upstream's doesn't have it.
  - All string keys referenced below (`trakt_lists_update_failed`, `library_local_tab_title`, `library_other`) already exist in `shared/src/commonMain/kotlin/com/nuvio/app/core/i18n/StringProvider.kt` — no new keys needed.

---

## Item 1 — Device session registration (CARRIED OVER, still not ported)

**Status:** Unchanged from the 2026-07-27/07-28 checks. `find NuvioMobile/shared -iname "*DeviceSessionRegistration*"` still returns empty (re-verified 2026-07-29).

Full spec (verbatim upstream Kotlin, the tvOS actual to write, and the two Swift hook points) is already written and unchanged at **`docs/upstream-port-plan-2026-07-27.md`** — implement Item 1 from that file as-is. Nothing to re-derive; this pointer just avoids duplicating ~150 lines of spec into this doc.

---

## Item 2 — Library incremental delta sync (`upstream` commits `1b05c222` "feat(library): add incremental delta sync", merged via `979d5680`)

**What it does:** Upstream replaced the library's sync mechanism. Old behavior: every save/remove marked a single `hasPendingPush` flag, and a push sent the **entire local library** (`sync_push_library` RPC) while a pull replaced the **entire local library** with the full server snapshot (`sync_pull_library` RPC), with a heuristic to avoid clobbering unsynced local edits. New behavior: a proper event-sourced delta sync —
- Local mutations (save/toggle/remove) now track **per-item pending upsert/delete keys** instead of one boolean flag.
- Push sends only the changed items (`sync_push_library_items` RPC to upsert, `sync_delete_library_items` RPC to delete), batched at 500 items.
- Pull does a one-time full snapshot bootstrap (`sync_pull_library` + `sync_get_library_delta_cursor`) only if never initialized before, then thereafter pulls only **new delta events since the last cursor** (`sync_pull_library_delta` RPC), paginated at 500/page, and applies them as upsert/delete operations keyed by an `eventId` cursor persisted alongside the library payload.
- A pure reconciliation module (`LibrarySyncReconciler`) merges server state with any pending local changes so a bootstrap pull never clobbers unsynced local edits, and delta application skips any event whose key has a pending local mutation (local wins until it's pushed).

**Why this matters for tvOS:** tvOS's `LibraryRepository`/`LibraryLocalState` were forked from upstream's pre-delta-sync version and still call the old `sync_push_library` (full push) / `sync_pull_library` (full pull) RPC names. If Supabase's RPC functions get renamed/replaced to match the new upstream protocol (`sync_push_library_items`, `sync_delete_library_items`, `sync_get_library_delta_cursor`, `sync_pull_library_delta` — check the Supabase project before starting, see Step 0), tvOS's old push/pull calls will silently fail or 404. Even if the old RPCs stay callable for a while, tvOS should move to the new protocol to stay compatible and to stop doing full-snapshot round-trips on every save.

**Step 0 — verify the RPC surface (do this first, it changes how urgent this is):** Check the Supabase project (dashboard or `supabase functions`/`rpc` list, however Christian normally inspects it — see `[[nuvio-cloud-api]]` / `docs/nuvio-cloud-api-reference.md` for the reference doc) for whether `sync_push_library` (old, full-replace) still exists alongside the new `sync_push_library_items` / `sync_delete_library_items` / `sync_get_library_delta_cursor` / `sync_pull_library_delta` RPCs. If the old RPC was **dropped**, this port is urgent (tvOS library sync is currently broken). If it's still there, this is important-but-not-urgent technical debt.

**Files to add (new), verbatim from upstream — no tvOS-specific changes needed, all imports already resolve in `shared/`:**

1. `shared/src/commonMain/kotlin/com/nuvio/app/features/library/sync/LibrarySyncAdapter.kt`:

```kotlin
package com.nuvio.app.features.library.sync

import com.nuvio.app.features.library.LibraryItem
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class LibrarySyncKey(
    @SerialName("content_id") val contentId: String,
    @SerialName("content_type") val contentType: String,
)

data class LibraryDeltaEvent(
    val eventId: Long,
    val operation: String,
    val item: LibraryItem,
)

interface LibrarySyncAdapter {
    suspend fun pullSnapshot(
        profileId: Int,
        pageSize: Int,
    ): List<LibraryItem>

    suspend fun getDeltaCursor(profileId: Int): Long

    suspend fun pullDelta(
        profileId: Int,
        sinceEventId: Long,
        limit: Int,
    ): List<LibraryDeltaEvent>

    suspend fun pushItems(
        profileId: Int,
        items: Collection<LibraryItem>,
    )

    suspend fun deleteItems(
        profileId: Int,
        keys: Collection<LibrarySyncKey>,
    )
}

fun LibraryItem.toLibrarySyncKey(): LibrarySyncKey =
    LibrarySyncKey(
        contentId = id,
        contentType = type,
    )
```

2. `shared/src/commonMain/kotlin/com/nuvio/app/features/library/sync/LibrarySyncPaging.kt`:

```kotlin
package com.nuvio.app.features.library.sync

internal const val librarySnapshotPageSize = 500
internal const val libraryDeltaPageSize = 500
internal const val libraryMutationBatchSize = 500

internal suspend fun <T> collectOffsetPages(
    pageSize: Int,
    fetchPage: suspend (limit: Int, offset: Int) -> List<T>,
): List<T> {
    require(pageSize > 0)

    val items = mutableListOf<T>()
    var offset = 0
    while (true) {
        val page = fetchPage(pageSize, offset)
        items += page
        if (page.size < pageSize) return items
        offset += pageSize
    }
}

internal suspend fun <T> consumeCursorPages(
    initialCursor: Long,
    pageSize: Int,
    fetchPage: suspend (cursor: Long, limit: Int) -> List<T>,
    applyPage: suspend (page: List<T>, cursor: Long) -> Long?,
): Long {
    require(pageSize > 0)

    var cursor = initialCursor
    while (true) {
        val page = fetchPage(cursor, pageSize)
        if (page.isEmpty()) return cursor

        val nextCursor = applyPage(page, cursor) ?: return cursor
        check(nextCursor > cursor)
        cursor = nextCursor
        if (page.size < pageSize) return cursor
    }
}

internal suspend fun <T> forEachMutationBatch(
    values: Collection<T>,
    batchSize: Int,
    sendBatch: suspend (List<T>) -> Unit,
) {
    require(batchSize > 0)
    values.chunked(batchSize).forEach { batch ->
        sendBatch(batch)
    }
}
```

3. `shared/src/commonMain/kotlin/com/nuvio/app/features/library/sync/SupabaseLibrarySyncAdapter.kt` (verbatim — `SupabaseProvider`, `putSyncOriginClientId`, `PosterShape` all already exist at these exact import paths in `shared/`):

```kotlin
package com.nuvio.app.features.library.sync

import com.nuvio.app.core.network.SupabaseProvider
import com.nuvio.app.core.sync.putSyncOriginClientId
import com.nuvio.app.features.home.PosterShape
import com.nuvio.app.features.library.LibraryItem
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.put

object SupabaseLibrarySyncAdapter : LibrarySyncAdapter {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    override suspend fun pullSnapshot(
        profileId: Int,
        pageSize: Int,
    ): List<LibraryItem> =
        collectOffsetPages(pageSize) { limit, offset ->
            val params = buildJsonObject {
                put("p_profile_id", profileId)
                put("p_limit", limit)
                put("p_offset", offset)
            }
            SupabaseProvider.client.postgrest
                .rpc("sync_pull_library", params)
                .decodeList<LibrarySyncItem>()
                .map(LibrarySyncItem::toLibraryItem)
        }

    override suspend fun getDeltaCursor(profileId: Int): Long {
        val params = buildJsonObject {
            put("p_profile_id", profileId)
        }
        return SupabaseProvider.client.postgrest
            .rpc("sync_get_library_delta_cursor", params)
            .decodeAs<Long>()
    }

    override suspend fun pullDelta(
        profileId: Int,
        sinceEventId: Long,
        limit: Int,
    ): List<LibraryDeltaEvent> {
        val params = buildJsonObject {
            put("p_profile_id", profileId)
            put("p_since_event_id", sinceEventId)
            put("p_limit", limit)
        }
        return SupabaseProvider.client.postgrest
            .rpc("sync_pull_library_delta", params)
            .decodeList<LibraryDeltaSyncItem>()
            .map { event ->
                LibraryDeltaEvent(
                    eventId = event.eventId,
                    operation = event.operation,
                    item = event.toLibraryItem(),
                )
            }
    }

    override suspend fun pushItems(
        profileId: Int,
        items: Collection<LibraryItem>,
    ) {
        forEachMutationBatch(items, libraryMutationBatchSize) { batch ->
            val params = buildJsonObject {
                put("p_profile_id", profileId)
                put("p_items", json.encodeToJsonElement(batch.map(LibraryItem::toSyncItem)))
                putSyncOriginClientId()
            }
            SupabaseProvider.client.postgrest.rpc("sync_push_library_items", params)
        }
    }

    override suspend fun deleteItems(
        profileId: Int,
        keys: Collection<LibrarySyncKey>,
    ) {
        forEachMutationBatch(keys, libraryMutationBatchSize) { batch ->
            val params = buildJsonObject {
                put("p_profile_id", profileId)
                put("p_keys", json.encodeToJsonElement(batch))
                putSyncOriginClientId()
            }
            SupabaseProvider.client.postgrest.rpc("sync_delete_library_items", params)
        }
    }
}

@Serializable
private data class LibrarySyncItem(
    @SerialName("content_id") override val contentId: String,
    @SerialName("content_type") override val contentType: String,
    override val name: String = "",
    override val poster: String? = null,
    @SerialName("poster_shape") override val posterShape: String = "POSTER",
    override val background: String? = null,
    override val description: String? = null,
    @SerialName("release_info") override val releaseInfo: String? = null,
    @SerialName("imdb_rating") override val imdbRating: Float? = null,
    override val genres: List<String> = emptyList(),
    @SerialName("addon_base_url") override val addonBaseUrl: String? = null,
    @SerialName("added_at") override val addedAt: Long = 0,
) : LibrarySyncFields

@Serializable
private data class LibraryDeltaSyncItem(
    @SerialName("event_id") val eventId: Long,
    val operation: String,
    @SerialName("content_id") override val contentId: String,
    @SerialName("content_type") override val contentType: String,
    override val name: String = "",
    override val poster: String? = null,
    @SerialName("poster_shape") override val posterShape: String = "POSTER",
    override val background: String? = null,
    override val description: String? = null,
    @SerialName("release_info") override val releaseInfo: String? = null,
    @SerialName("imdb_rating") override val imdbRating: Float? = null,
    override val genres: List<String> = emptyList(),
    @SerialName("addon_base_url") override val addonBaseUrl: String? = null,
    @SerialName("added_at") override val addedAt: Long = 0,
) : LibrarySyncFields

private interface LibrarySyncFields {
    val contentId: String
    val contentType: String
    val name: String
    val poster: String?
    val posterShape: String
    val background: String?
    val description: String?
    val releaseInfo: String?
    val imdbRating: Float?
    val genres: List<String>
    val addonBaseUrl: String?
    val addedAt: Long
}

private fun LibrarySyncFields.toLibraryItem(): LibraryItem =
    LibraryItem(
        id = contentId,
        type = contentType,
        name = name,
        poster = poster,
        banner = background,
        description = description,
        releaseInfo = releaseInfo,
        imdbRating = imdbRating?.toString(),
        genres = genres,
        posterShape = posterShape.toPosterShape(),
        addonBaseUrl = addonBaseUrl,
        savedAtEpochMs = addedAt,
    )

private fun LibraryItem.toSyncItem(): LibrarySyncItem =
    LibrarySyncItem(
        contentId = id,
        contentType = type,
        name = name,
        poster = poster,
        posterShape = posterShape.toSyncName(),
        background = banner,
        description = description,
        releaseInfo = releaseInfo,
        imdbRating = imdbRating?.toFloatOrNull(),
        genres = genres,
        addonBaseUrl = addonBaseUrl,
        addedAt = savedAtEpochMs,
    )

private fun String.toPosterShape(): PosterShape =
    when (trim().uppercase()) {
        "LANDSCAPE" -> PosterShape.Landscape
        "SQUARE" -> PosterShape.Square
        else -> PosterShape.Poster
    }

private fun PosterShape.toSyncName(): String =
    when (this) {
        PosterShape.Poster -> "POSTER"
        PosterShape.Square -> "SQUARE"
        PosterShape.Landscape -> "LANDSCAPE"
    }
```

4. `shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibrarySyncReconciler.kt` (pure logic, no dependencies beyond `LibraryItem`/the new sync types — verbatim):

```kotlin
package com.nuvio.app.features.library

import com.nuvio.app.features.library.sync.LibraryDeltaEvent
import com.nuvio.app.features.library.sync.LibrarySyncKey
import com.nuvio.app.features.library.sync.toLibrarySyncKey

internal data class LibrarySnapshotReconciliation(
    val itemsByKey: MutableMap<String, LibraryItem>,
    val pendingUpsertKeysByKey: MutableMap<String, LibrarySyncKey>,
    val pendingDeleteKeysByKey: MutableMap<String, LibrarySyncKey>,
    val preservedLocalItems: Boolean,
)

internal data class LibraryDeltaReconciliation(
    val itemsByKey: MutableMap<String, LibraryItem>,
    val changed: Boolean,
    val cursorEventId: Long,
)

internal fun reconcileLibrarySnapshot(
    serverItems: Collection<LibraryItem>,
    localItemsByKey: Map<String, LibraryItem>,
    pendingUpsertKeysByKey: Map<String, LibrarySyncKey>,
    pendingDeleteKeysByKey: Map<String, LibrarySyncKey>,
    preserveLegacyLocalWhenServerEmpty: Boolean,
): LibrarySnapshotReconciliation {
    val serverItemsByKey = serverItems.associateByTo(mutableMapOf()) {
        libraryItemKey(it.id, it.type)
    }
    val pendingUpserts = pendingUpsertKeysByKey.toMutableMap()
    val pendingDeletes = pendingDeleteKeysByKey.toMutableMap()
    val migrateLegacyLocalItems =
        preserveLegacyLocalWhenServerEmpty &&
            serverItemsByKey.isEmpty() &&
            localItemsByKey.isNotEmpty() &&
            pendingUpserts.isEmpty() &&
            pendingDeletes.isEmpty()

    if (migrateLegacyLocalItems) {
        localItemsByKey.forEach { (key, item) ->
            pendingUpserts[key] = item.toLibrarySyncKey()
        }
    } else {
        pendingDeletes.keys.forEach(serverItemsByKey::remove)
        pendingUpserts.keys.forEach { key ->
            localItemsByKey[key]?.let { item -> serverItemsByKey[key] = item }
        }
    }

    return LibrarySnapshotReconciliation(
        itemsByKey = if (migrateLegacyLocalItems) {
            localItemsByKey.toMutableMap()
        } else {
            serverItemsByKey
        },
        pendingUpsertKeysByKey = pendingUpserts,
        pendingDeleteKeysByKey = pendingDeletes,
        preservedLocalItems = migrateLegacyLocalItems || pendingUpserts.isNotEmpty() || pendingDeletes.isNotEmpty(),
    )
}

internal fun reconcileLibraryDelta(
    events: Collection<LibraryDeltaEvent>,
    currentItemsByKey: Map<String, LibraryItem>,
    pendingUpsertKeysByKey: Map<String, LibrarySyncKey>,
    pendingDeleteKeysByKey: Map<String, LibrarySyncKey>,
    currentCursorEventId: Long,
): LibraryDeltaReconciliation {
    val items = currentItemsByKey.toMutableMap()

    events.sortedBy(LibraryDeltaEvent::eventId).forEach { event ->
        val key = libraryItemKey(event.item.id, event.item.type)
        if (key in pendingUpsertKeysByKey || key in pendingDeleteKeysByKey) return@forEach

        when (event.operation.trim().lowercase()) {
            "upsert" -> items[key] = event.item
            "delete" -> items.remove(key)
        }
    }

    return LibraryDeltaReconciliation(
        itemsByKey = items,
        changed = items != currentItemsByKey,
        cursorEventId = maxOf(
            currentCursorEventId,
            events.maxOfOrNull(LibraryDeltaEvent::eventId) ?: currentCursorEventId,
        ),
    )
}
```

5. `shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryStoragePayload.kt` (verbatim — replaces the private `StoredLibraryPayload`/json currently inlined at the top of tvOS's `LibraryRepository.kt`; `LibraryItem` is already `@Serializable` in `shared/`, and `LibraryLocalSnapshot` will have the new `deltaCursorEventId`/`deltaInitialized`/`pendingUpsertKeys`/`pendingDeleteKeys` fields after Step 2b below):

```kotlin
package com.nuvio.app.features.library

import com.nuvio.app.features.library.sync.LibrarySyncKey
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
internal data class StoredLibraryPayload(
    val items: List<LibraryItem> = emptyList(),
    val deltaCursorEventId: Long = 0L,
    val deltaInitialized: Boolean = false,
    val pendingUpsertKeys: List<LibrarySyncKey> = emptyList(),
    val pendingDeleteKeys: List<LibrarySyncKey> = emptyList(),
)

internal object LibraryStoragePayloadCodec {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    fun decode(payload: String): StoredLibraryPayload =
        runCatching {
            json.decodeFromString<StoredLibraryPayload>(payload)
        }.getOrDefault(StoredLibraryPayload())

    fun encode(snapshot: LibraryLocalSnapshot): String =
        json.encodeToString(
            StoredLibraryPayload(
                items = snapshot.items.sortedByDescending(LibraryItem::savedAtEpochMs),
                deltaCursorEventId = snapshot.deltaCursorEventId,
                deltaInitialized = snapshot.deltaInitialized,
                pendingUpsertKeys = snapshot.pendingUpsertKeys,
                pendingDeleteKeys = snapshot.pendingDeleteKeys,
            ),
        )
}
```

**Step 2a — rewrite `shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryLocalState.kt`.** This file has NO tvOS-specific deviations from upstream (no toast/string-resource usage), so port it **verbatim** from upstream (this is the exact new file, already fetched and diffed against the current tvOS version — the changes replace the single `hasPendingPush` boolean with cursor/delta-key tracking throughout):

```kotlin
package com.nuvio.app.features.library

import com.nuvio.app.features.library.sync.LibraryDeltaEvent
import com.nuvio.app.features.library.sync.LibrarySyncKey
import com.nuvio.app.features.library.sync.toLibrarySyncKey
import kotlinx.atomicfu.locks.SynchronizedObject
import kotlinx.atomicfu.locks.synchronized
import kotlinx.coroutines.Job

data class LibraryProfileToken(
    val profileId: Int,
    val generation: Long,
)

internal data class LibraryLocalSnapshot(
    val token: LibraryProfileToken,
    val revision: Long,
    val contentRevision: Long,
    val hasLoaded: Boolean,
    val isLoading: Boolean,
    val items: List<LibraryItem>,
    val deltaCursorEventId: Long,
    val deltaInitialized: Boolean,
    val pendingUpsertKeys: List<LibrarySyncKey>,
    val pendingDeleteKeys: List<LibrarySyncKey>,
) {
    val hasPendingPush: Boolean
        get() = pendingUpsertKeys.isNotEmpty() || pendingDeleteKeys.isNotEmpty()
}

data class LibraryStateTransition(
    val snapshot: LibraryLocalSnapshot,
    val detachedPushJob: Job?,
)

data class LibraryLocalMutation(
    val snapshot: LibraryLocalSnapshot,
    val affectedCount: Int,
)

data class LibraryLocalToggleResult(
    val snapshot: LibraryLocalSnapshot,
    val isSaved: Boolean,
)

data class LibraryServerItemsApplyResult(
    val snapshot: LibraryLocalSnapshot,
    val preservedLocalItems: Boolean,
)

data class LibraryPushJobInstallResult(
    val installed: Boolean,
    val detachedPushJob: Job?,
)

/**
 * Owns the profile-scoped local-library state behind one lock.
 *
 * Callers only receive copied item lists, so sorting or serializing a snapshot never traverses
 * the live mutable map while another thread replaces or edits it.
 */
class LibraryLocalState {
    private val lock = SynchronizedObject()

    private var hasLoaded = false
    private var currentProfileId = 1
    private var profileGeneration = 0L
    private var revision = 0L
    private var contentRevision = 0L
    private var isLoading = false
    private var itemsById: MutableMap<String, LibraryItem> = mutableMapOf()
    private var deltaCursorEventId = 0L
    private var deltaInitialized = false
    private var pendingUpsertKeysByKey: MutableMap<String, LibrarySyncKey> = mutableMapOf()
    private var pendingDeleteKeysByKey: MutableMap<String, LibrarySyncKey> = mutableMapOf()
    private var pushJob: Job? = null

    fun snapshot(): LibraryLocalSnapshot = synchronized(lock) {
        snapshotLocked()
    }

    fun currentTokenIfLoaded(profileId: Int): LibraryProfileToken? = synchronized(lock) {
        if (!hasLoaded || currentProfileId != profileId) {
            null
        } else {
            tokenLocked()
        }
    }

    fun isCurrent(token: LibraryProfileToken): Boolean = synchronized(lock) {
        isCurrentLocked(token)
    }

    fun isCurrent(snapshot: LibraryLocalSnapshot): Boolean = synchronized(lock) {
        isCurrentLocked(snapshot)
    }

    fun isContentCurrent(snapshot: LibraryLocalSnapshot): Boolean = synchronized(lock) {
        isContentCurrentLocked(snapshot)
    }

    fun runIfCurrent(snapshot: LibraryLocalSnapshot, block: () -> Unit): Boolean = synchronized(lock) {
        if (!isCurrentLocked(snapshot)) {
            false
        } else {
            block()
            true
        }
    }

    fun runIfContentCurrent(snapshot: LibraryLocalSnapshot, block: () -> Unit): Boolean = synchronized(lock) {
        if (!isContentCurrentLocked(snapshot)) {
            false
        } else {
            block()
            true
        }
    }

    fun runIfTokenCurrent(token: LibraryProfileToken, block: () -> Unit): Boolean = synchronized(lock) {
        if (!isCurrentLocked(token)) {
            false
        } else {
            block()
            true
        }
    }

    fun beginProfileLoad(profileId: Int): LibraryStateTransition = synchronized(lock) {
        val detachedPushJob = pushJob
        pushJob = null
        currentProfileId = profileId
        profileGeneration += 1L
        revision += 1L
        contentRevision += 1L
        hasLoaded = false
        isLoading = true
        itemsById = mutableMapOf()
        deltaCursorEventId = 0L
        deltaInitialized = false
        pendingUpsertKeysByKey = mutableMapOf()
        pendingDeleteKeysByKey = mutableMapOf()
        LibraryStateTransition(
            snapshot = snapshotLocked(),
            detachedPushJob = detachedPushJob,
        )
    }

    fun completeProfileLoad(
        token: LibraryProfileToken,
        activeProfileId: Int,
        items: Collection<LibraryItem>,
        deltaCursorEventId: Long = 0L,
        deltaInitialized: Boolean = false,
        pendingUpsertKeys: Collection<LibrarySyncKey> = emptyList(),
        pendingDeleteKeys: Collection<LibrarySyncKey> = emptyList(),
    ): LibraryLocalSnapshot? = synchronized(lock) {
        if (activeProfileId != token.profileId || !isCurrentLocked(token)) {
            return@synchronized null
        }
        itemsById = items.associateByTo(mutableMapOf()) { libraryItemKey(it.id, it.type) }
        this.deltaCursorEventId = deltaCursorEventId.coerceAtLeast(0L)
        this.deltaInitialized = deltaInitialized
        pendingUpsertKeysByKey = pendingUpsertKeys
            .associateByTo(mutableMapOf()) { libraryItemKey(it.contentId, it.contentType) }
            .filterToExistingItems(itemsById)
        pendingDeleteKeysByKey = pendingDeleteKeys
            .associateByTo(mutableMapOf()) { libraryItemKey(it.contentId, it.contentType) }
            .apply { pendingUpsertKeysByKey.keys.forEach(::remove) }
        pendingDeleteKeysByKey.keys.forEach(itemsById::remove)
        hasLoaded = true
        isLoading = false
        revision += 1L
        contentRevision += 1L
        snapshotLocked()
    }

    fun reset(): LibraryStateTransition = synchronized(lock) {
        val detachedPushJob = pushJob
        pushJob = null
        currentProfileId = 1
        profileGeneration += 1L
        revision += 1L
        contentRevision += 1L
        hasLoaded = false
        isLoading = false
        itemsById = mutableMapOf()
        deltaCursorEventId = 0L
        deltaInitialized = false
        pendingUpsertKeysByKey = mutableMapOf()
        pendingDeleteKeysByKey = mutableMapOf()
        LibraryStateTransition(
            snapshot = snapshotLocked(),
            detachedPushJob = detachedPushJob,
        )
    }

    fun markPullStarted(token: LibraryProfileToken): LibraryLocalSnapshot? = synchronized(lock) {
        if (!isCurrentLocked(token)) return@synchronized null
        snapshotLocked()
    }

    fun applyServerItems(
        pullSnapshot: LibraryLocalSnapshot,
        serverItems: Collection<LibraryItem>,
        cursorEventId: Long = 0L,
    ): LibraryServerItemsApplyResult? = synchronized(lock) {
        if (!isCurrentLocked(pullSnapshot.token)) return@synchronized null

        val reconciliation = reconcileLibrarySnapshot(
            serverItems = serverItems,
            localItemsByKey = itemsById,
            pendingUpsertKeysByKey = pendingUpsertKeysByKey,
            pendingDeleteKeysByKey = pendingDeleteKeysByKey,
            preserveLegacyLocalWhenServerEmpty = !pullSnapshot.deltaInitialized,
        )
        if (itemsById != reconciliation.itemsByKey) {
            contentRevision += 1L
        }
        itemsById = reconciliation.itemsByKey
        pendingUpsertKeysByKey = reconciliation.pendingUpsertKeysByKey
        pendingDeleteKeysByKey = reconciliation.pendingDeleteKeysByKey
        deltaCursorEventId = cursorEventId.coerceAtLeast(0L)
        deltaInitialized = true
        hasLoaded = true
        isLoading = false
        revision += 1L
        LibraryServerItemsApplyResult(
            snapshot = snapshotLocked(),
            preservedLocalItems = reconciliation.preservedLocalItems,
        )
    }

    fun applyDeltaEvents(
        token: LibraryProfileToken,
        events: Collection<LibraryDeltaEvent>,
    ): LibraryLocalSnapshot? = synchronized(lock) {
        if (!isCurrentLocked(token)) return@synchronized null

        val reconciliation = reconcileLibraryDelta(
            events = events,
            currentItemsByKey = itemsById,
            pendingUpsertKeysByKey = pendingUpsertKeysByKey,
            pendingDeleteKeysByKey = pendingDeleteKeysByKey,
            currentCursorEventId = deltaCursorEventId,
        )
        if (reconciliation.changed) {
            itemsById = reconciliation.itemsByKey
            contentRevision += 1L
        }
        deltaCursorEventId = reconciliation.cursorEventId
        deltaInitialized = true
        revision += 1L
        snapshotLocked()
    }

    fun upsert(item: LibraryItem): LibraryLocalSnapshot = synchronized(lock) {
        val key = libraryItemKey(item.id, item.type)
        itemsById[key] = item
        pendingUpsertKeysByKey[key] = item.toLibrarySyncKey()
        pendingDeleteKeysByKey.remove(key)
        revision += 1L
        contentRevision += 1L
        snapshotLocked()
    }

    fun toggle(item: LibraryItem): LibraryLocalToggleResult = synchronized(lock) {
        val key = libraryItemKey(item.id, item.type)
        val removedItem = itemsById.remove(key)
        val isSaved = if (removedItem != null) {
            pendingUpsertKeysByKey.remove(key)
            pendingDeleteKeysByKey[key] = removedItem.toLibrarySyncKey()
            false
        } else {
            itemsById[key] = item
            pendingUpsertKeysByKey[key] = item.toLibrarySyncKey()
            pendingDeleteKeysByKey.remove(key)
            true
        }
        revision += 1L
        contentRevision += 1L
        LibraryLocalToggleResult(
            snapshot = snapshotLocked(),
            isSaved = isSaved,
        )
    }

    fun removeById(id: String): LibraryLocalMutation = synchronized(lock) {
        val removedEntries = itemsById
            .filterValues { item -> item.id == id }
        removedEntries.forEach { (key, item) ->
            itemsById.remove(key)
            pendingUpsertKeysByKey.remove(key)
            pendingDeleteKeysByKey[key] = item.toLibrarySyncKey()
        }
        val affectedCount = removedEntries.size
        if (affectedCount > 0) {
            revision += 1L
            contentRevision += 1L
        }
        LibraryLocalMutation(
            snapshot = snapshotLocked(),
            affectedCount = affectedCount,
        )
    }

    fun remove(id: String, type: String): LibraryLocalMutation = synchronized(lock) {
        val key = libraryItemKey(id, type)
        val removedItem = itemsById.remove(key)
        val affectedCount = if (removedItem != null) 1 else 0
        if (removedItem != null) {
            pendingUpsertKeysByKey.remove(key)
            pendingDeleteKeysByKey[key] = removedItem.toLibrarySyncKey()
            revision += 1L
            contentRevision += 1L
        }
        LibraryLocalMutation(
            snapshot = snapshotLocked(),
            affectedCount = affectedCount,
        )
    }

    fun contains(id: String, type: String): Boolean = synchronized(lock) {
        itemsById.containsKey(libraryItemKey(id, type))
    }

    fun containsId(id: String): Boolean = synchronized(lock) {
        itemsById.values.any { it.id == id }
    }

    fun findById(id: String): LibraryItem? = synchronized(lock) {
        itemsById.values.firstOrNull { it.id == id }
    }

    fun installPushJob(
        snapshot: LibraryLocalSnapshot,
        job: Job,
    ): LibraryPushJobInstallResult = synchronized(lock) {
        if (!isCurrentLocked(snapshot)) {
            LibraryPushJobInstallResult(installed = false, detachedPushJob = null)
        } else {
            val detachedPushJob = pushJob
            pushJob = job
            LibraryPushJobInstallResult(installed = true, detachedPushJob = detachedPushJob)
        }
    }

    fun clearPushJob(job: Job) {
        synchronized(lock) {
            if (pushJob === job) pushJob = null
        }
    }

    fun markPushCompleted(snapshot: LibraryLocalSnapshot): LibraryLocalSnapshot? = synchronized(lock) {
        if (!isCurrentLocked(snapshot)) {
            null
        } else {
            pendingUpsertKeysByKey.clear()
            pendingDeleteKeysByKey.clear()
            revision += 1L
            snapshotLocked()
        }
    }

    private fun tokenLocked(): LibraryProfileToken =
        LibraryProfileToken(
            profileId = currentProfileId,
            generation = profileGeneration,
        )

    private fun snapshotLocked(): LibraryLocalSnapshot =
        LibraryLocalSnapshot(
            token = tokenLocked(),
            revision = revision,
            contentRevision = contentRevision,
            hasLoaded = hasLoaded,
            isLoading = isLoading,
            items = itemsById.values.toList(),
            deltaCursorEventId = deltaCursorEventId,
            deltaInitialized = deltaInitialized,
            pendingUpsertKeys = pendingUpsertKeysByKey.values.toList(),
            pendingDeleteKeys = pendingDeleteKeysByKey.values.toList(),
        )

    private fun isCurrentLocked(token: LibraryProfileToken): Boolean =
        currentProfileId == token.profileId && profileGeneration == token.generation

    private fun isCurrentLocked(snapshot: LibraryLocalSnapshot): Boolean =
        isCurrentLocked(snapshot.token) && revision == snapshot.revision

    private fun isContentCurrentLocked(snapshot: LibraryLocalSnapshot): Boolean =
        isCurrentLocked(snapshot.token) && contentRevision == snapshot.contentRevision
}

private fun MutableMap<String, LibrarySyncKey>.filterToExistingItems(
    itemsById: Map<String, LibraryItem>,
): MutableMap<String, LibrarySyncKey> =
    apply {
        keys.retainAll(itemsById.keys)
    }

internal fun libraryItemKey(id: String, type: String): String =
    "${type.trim().lowercase()}:${id.trim()}"
```

⚠️ Note: upstream's `LibraryLocalSnapshot`/`LibraryLocalState` class are declared `internal` in this new version (tvOS's current copy has them non-internal / `data class` without the modifier — check whether any Swift-facing or other-module caller reaches into `LibraryLocalSnapshot` directly; if `LibraryRepository` is the only consumer, keeping `internal` is fine and matches upstream. `LibraryProfileToken` stays public since callers outside the file reference `LibraryProfileToken` — confirm by searching `shared/` for external usages before committing to `internal`).

**Step 2b — rewrite `shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryRepository.kt`.** This is where tvOS-specific naming must be preserved. Use upstream's new logic (below) but with these substitutions applied throughout (mechanical, not semantic changes):

- Remove the old inlined `StoredLibraryPayload`/`LibrarySyncItem`/`json` (now live in `LibraryStoragePayload.kt` / `sync/SupabaseLibrarySyncAdapter.kt`).
- Remove the old direct `io.github.jan.supabase.postgrest.*` / `SupabaseProvider` imports and the old `pullAllLibrarySyncItems` private function — replaced by calling `syncAdapter` (add `internal var syncAdapter: LibrarySyncAdapter = SupabaseLibrarySyncAdapter` exactly as upstream does — keep it swappable for tests).
- Keep tvOS's `syncScope = CoroutineScope(SupervisorJob() + Dispatchers.Default + uncaughtCoroutineLogger("LibraryRepository"))` (don't drop the `uncaughtCoroutineLogger` — that's a tvOS-only addition, not in upstream).
- Replace `NuvioToastController.show(...)` → `ToastControllerProvider.controller.show(...)`.
- Replace `getString(Res.string.trakt_lists_update_failed)` → `resourceString("Failed to update Trakt lists", StringKey.trakt_lists_update_failed)` (drop the `Res`/`StringResource`/`getString`/`runBlocking` compose-resources imports entirely — not used elsewhere in tvOS's `shared/`).
- Replace the two upstream helper functions `localizedStringOrDefault` / `localizedLibraryOtherTitle` (compose-resources based) with tvOS's existing pattern: `resourceString(DEFAULT_LOCAL_LIBRARY_TAB_TITLE, StringKey.library_local_tab_title)` and `resourceString(DEFAULT_LIBRARY_OTHER_TITLE, StringKey.library_other)` — i.e. keep tvOS's current simpler helpers, just apply them to the otherwise-unchanged rest of the file.
- Keep `fun libraryTabsWithLocal(...)` / `fun libraryMembershipWithLocal(...)` / `fun String.toLibraryDisplayTitle()` non-`internal` (public) exactly as tvOS currently has them — upstream also has them non-private at file scope, no change needed there.

Structurally, adopt upstream's new `pullFromServer`/`pullLibraryDelta`/`pushToServer`/`persist` bodies (they now call `syncAdapter.pullSnapshot/getDeltaCursor/pullDelta/pushItems/deleteItems` and `LibraryStoragePayloadCodec.encode/decode`, and `pushToServer` now takes a `delayMs` param and pushes only `pendingUpsertKeys`/`pendingDeleteKeys` instead of the whole item list). The full upstream method bodies to adapt are in the diff of `composeApp/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryRepository.kt` between commits `88d3cbdf` and `979d5680` in `NuvioMobile/` (`cd NuvioMobile && git diff 88d3cbdf..979d5680 -- composeApp/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryRepository.kt`, or `git show 979d5680:composeApp/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryRepository.kt` for the full new file) — apply the substitutions above while porting.

**Step 2c — Tests (optional but recommended, upstream added 3 test files with good coverage of the reconciler/paging/delta logic):**
- `shared/src/commonTest/kotlin/com/nuvio/app/features/library/LibraryDeltaStateTest.kt`
- `shared/src/commonTest/kotlin/com/nuvio/app/features/library/LibrarySyncReconcilerTest.kt`
- `shared/src/commonTest/kotlin/com/nuvio/app/features/library/sync/LibrarySyncPagingTest.kt`

Fetch each via `git show 979d5680:composeApp/src/commonTest/kotlin/com/nuvio/app/features/library/<name>.kt` (or the `sync/` subpath for the paging test) from `NuvioMobile/` — these are pure logic tests against internal types, should port with zero adaptation since they don't touch UI/toast/string-resource code. Add to `shared/src/commonTest` (Kotlin/Native + JVM common test source set — verify the tvOS build already runs `commonTest`; per `[[nuvio-tvos-build-setup]]` the standard per-batch verify command already includes `:composeApp:iosSimulatorArm64Test`, check if there's a `:shared:` test task equivalent and add it to the verify command if so).

**Step 2d — verify.** Standard per-batch build command from `[[nuvio-tvos-build-setup]]`: `./gradlew :shared:compileKotlinIosSimulatorArm64 :shared:linkDebugFrameworkTvosSimulatorArm64 :composeApp:compileKotlinIosSimulatorArm64 :composeApp:iosSimulatorArm64Test -Pnuvio.android.distribution=full`. No Swift call sites should need changes — `LibraryRepository`'s public API (`toggleSaved`, `save`, `remove`, `isSaved`, `savedItem`, `libraryListTabs`, `uiState`, etc.) is unchanged; this is an internal sync-mechanism swap.

---

## Item 3 — Auth error sanitization (`upstream` commit `d55ed7ae` "fix(auth): sanitize authentication errors")

**What it does:** Small, self-contained fix in `AuthRepository.signUpWithEmail`/`signInWithEmail`. Previously errors surfaced `e.message` directly to the user, which could leak raw exception internals/stack info. Now it extracts a clean message specifically from Supabase's typed exceptions (`AuthRestException.errorDescription`, falling back to `RestException.description`), and only falls back to the generic "sign up/in failed" string if neither typed cause is present (never surfaces raw `e.message`).

**Why this matters for tvOS:** tvOS's `AuthRepository` (`shared/src/commonMain/kotlin/com/nuvio/app/core/auth/AuthRepository.kt`) still has the old `e.message ?: resourceString(...)` pattern at the equivalent `signUpWithEmail`/`signInWithEmail` call sites (confirmed via grep, lines ~125 and ~136) — same UX/security gap upstream just fixed. tvOS's `AuthRepository` already has a private `findCause<T>()` inline extension (used elsewhere for `RestException` 401/403 detection), so this ports cleanly by reusing it.

**Change to make** in `shared/src/commonMain/kotlin/com/nuvio/app/core/auth/AuthRepository.kt`:

1. Add import: `import io.github.jan.supabase.auth.exception.AuthRestException` (alongside the existing `import io.github.jan.supabase.exceptions.RestException`).

2. Replace:
```kotlin
        _error.value = e.message ?: resourceString("Sign-up failed", StringKey.auth_sign_up_failed)
```
with:
```kotlin
        _error.value = e.safeAuthErrorDescription()
            ?: resourceString("Sign-up failed", StringKey.auth_sign_up_failed)
```

3. Replace:
```kotlin
        _error.value = e.message ?: resourceString("Sign-in failed", StringKey.auth_sign_in_failed)
```
with:
```kotlin
        _error.value = e.safeAuthErrorDescription()
            ?: resourceString("Sign-in failed", StringKey.auth_sign_in_failed)
```

4. Add this private extension function near the existing `findCause<T>()` helper (reuses it, so keep both in the same file):
```kotlin
    private fun Throwable.safeAuthErrorDescription(): String? =
        findCause<AuthRestException>()
            ?.errorDescription
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: findCause<RestException>()
                ?.description
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
```

Do **not** touch the `signOut`/`deleteAccount` error paths (lines ~174, ~216) — upstream's fix is scoped to sign-up/sign-in only, leave the rest as-is unless a future upstream commit extends it.

**Verify:** same build command as Item 2 (this file compiles as part of `:shared:compileKotlinIosSimulatorArm64`). No Swift call site changes needed — `AuthRepository.error`'s type/consumers are unchanged, only the string content improves.

---

## Not applicable this run

Same rule as every prior check — composeApp-only Compose UI, Android manifest/resources, and anything with no `shared/` counterpart is out of scope. Nothing else in the `88d3cbdf..979d5680` diff falls outside Items 1–3 (the diff only touched the auth + library files covered above).

**Not re-checked this run** (no change expected): MPVKit tags, `upstream/simkl` branch (moved `26e7b23f`→`247afcbf`, still unmerged into `cmp-rewrite`, still out of scope).

**Next scheduled check:** verify Items 2 and 3 landed (`find shared -iname "LibrarySyncReconciler.kt"` and `grep -n safeAuthErrorDescription shared/.../AuthRepository.kt` should both be non-empty once done) before re-flagging; re-confirm Item 1 the same way as always (`find NuvioMobile/shared -iname "*DeviceSessionRegistration*"`).
