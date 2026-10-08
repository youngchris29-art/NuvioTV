# Player P2 spec: preview store, harvest, chapters, aspect modes, settings (2026-10-07)

Scope: plan `docs/player-revamp-plan-2026-10-06.md` § "Batch P2" items A12 (harvest store), A6 (chapters on mpv), A7 (aspect modes), and the P2 settings rows. Sibling spec `docs/research/player-p2-spec-scrub.md` owns the pan recogniser, `ScrubGestureArbiter`, the `.scrubbing` mode in `TransportPreview`, the preview card drawing, and the `previewFrame` plumbing in the bar. This spec owns the store, the libmpv node helper, the harvest, chapters, aspect, settings and strings. Read-only basis: clone `~/Claude/Projects/NuvioMobile-player` at `0c10ca4a4` (branch `claude/player-p2`). All paths below are under `iosApp/NuvioTV/` unless they start with `shared/` or `iosApp/`.

## 0. Rules carried from P1 (non-negotiable)

1. **The main thread never calls an mpv function that takes the core lock** (`mpv_get_property*`, `mpv_command*`, `mpv_set_property*`). Comment at `Screens/MPVPlayerView.swift:196-201`; every read goes through `eventQueue` (`:121`) the way `refreshBufferedAsync` does (`:1577-1601`). The harvest's `screenshot-raw` is the heaviest call this file will make; it is `eventQueue`-only.
2. **Teardown (BUG-141).** `destroyPlayer` (`:2372-2387`) runs only from `deinit` (`:2369`), unsets the wakeup before `mpv_terminate_destroy`. Every new `eventQueue` block uses `[weak self]` + `guard let self, self.mpv != nil`, exactly like `issueSeek` (`:2111-2113`). A strong `self` held for the length of a block means `deinit` cannot overlap it, so a running `screenshot-raw` is never cut by `mpv_terminate_destroy`. Never form a new weak reference to the controller inside `deinit`/`destroyPlayer`. Work that leaves `eventQueue` (JPEG encode, downscale) carries **only** copied bytes and the store reference, never the controller or the `mpv` handle.
3. Stage by explicit paths in the clone; MPVKit is a symlink over the gitlink.

## 1. Data contract shared with the scrub spec

`Screens/Player/TransportBarModel.swift` already declares `TransportChapter(title:sec:)` (`:6`) and `@Published var chapters` (`:18`), and `PlayerTransportBar.swift:267-270` already draws a 2 pt tick (white 60 %, `h * 2` tall) per chapter. P2 only has to fill `chapters`. Fields this spec adds to `TransportBarModel`:

```swift
@Published var aspectMode: PlayerAspectMode = .fit
@Published var aspectFlash: String? = nil          // non-nil for 2 s after a cycle
@Published var previewFrames: Int = 0              // store count, for the probe
func chapterTitle(at sec: Double) -> String? { PlayerChapters.title(at: sec, in: chapters) }
```

Fields on `MPVPlaybackState` (`MPVPlayerView.swift:28-67`):

```swift
weak var previewStore: SeekPreviewStore?           // set in viewDidLoad; dies with the controller
var seekToChapter: ((Double) -> Void)?             // set in viewDidLoad, like selectAudio (:361)
@Published var previewStoreSummary: String = ""   // Info-tab memory row (§3.6)
```

The scrub spec reads `state.previewStore?.thumbnail(near:)` (async) and `state.transport.chapterTitle(at:)`. It never touches the harvest. The `previewFrame` property and the card are its side.

## 2. `Screens/Player/SeekPreviewStore.swift` (new)

```swift
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

protocol PreviewFrameCodec: Sendable {
    func encode(_ image: CGImage) -> Data?
    func decode(_ data: Data) -> CGImage?
}

struct JPEGPreviewCodec: PreviewFrameCodec {   // ImageIO, quality 0.6
    func encode(_ image: CGImage) -> Data?     // CGImageDestinationCreateWithData(…, UTType.jpeg.identifier as CFString, 1, nil), kCGImageDestinationLossyCompressionQuality: 0.6
    func decode(_ data: Data) -> CGImage?      // CGImageSourceCreateWithData → CGImageSourceCreateImageAtIndex(0)
}

actor SeekPreviewStore {
    static let defaultMaxEntries = 200
    static let defaultMaxBytes = 6 * 1024 * 1024
    static let targetWidth = 320
    let streamKey: String
    init(streamKey: String, codec: PreviewFrameCodec = JPEGPreviewCodec(),
         maxEntries: Int = defaultMaxEntries, maxBytes: Int = defaultMaxBytes)

    func insert(_ image: CGImage, at sec: Double)
    func thumbnail(near sec: Double, tolerance: Double? = nil) -> CGImage?
    func sampleSpacing() -> Double
    func coverage() -> [ClosedRange<Double>]
    func removeAll()
    var count: Int { get }
    var byteCount: Int { get }
}
```

Behaviour, exactly:

- **Storage:** `[Entry]` kept sorted by `sec`, `Entry { sec: Double; jpeg: Data; seq: UInt64 }`; `seq` is a monotonically increasing insertion counter. Lookups binary-search by `sec`.
- **insert:** ignore non-finite or negative `sec`, and images whose `width > targetWidth` (the caller downscales; the store does not). Encode with the codec; a nil encode is dropped. An existing entry within **1.0 s** of `sec` is replaced (new data, new `seq`). Then evict the entry with the **smallest `seq`** (insertion recency; lookups do not refresh) while `count > maxEntries || byteCount > maxBytes`. Invalidate the decode cache if its entry was replaced or evicted.
- **thumbnail(near:tolerance:):** `tol = tolerance ?? min(max(sampleSpacing(), 5), 30)`. Find the entry with the smallest `|entry.sec − sec|`; ties go to the earlier entry; return nil when the distance exceeds `tol`. Decode through a one-entry cache (`lastDecoded: (seq, CGImage)`) so a scrub that sits still decodes once.
- **sampleSpacing():** the median of the gaps between consecutive sorted stamps, counting only gaps ≤ 60 s (a seek leaves a hole that is not spacing); fewer than two such gaps → **10**. The plan called this the "GOP estimate"; harvested stamps are 10 s apart, so it measures harvest spacing, and P3's keyframe decoder will pull it down to the real GOP. The 30 s ceiling keeps a sparse store from showing a frame from another scene.
- **coverage():** walk sorted stamps, join consecutive stamps whose gap ≤ `2 × sampleSpacing()` into one range, a lone stamp is `s...s`. For a later filmstrip and the probe; not drawn in P2.
- **removeAll():** empties entries and the decode cache.
- **Memory:** 320 × 180 at q 0.6 is about 12–25 KB, so 200 entries stay near 3–5 MB; `maxBytes` is the hard cap (device pass item 8 checks ≤ 10 MB RSS growth).

Lifetime: one instance per controller, created in `viewDidLoad` (`:349`), held strongly by the controller (`private var previewStore: SeekPreviewStore?`), handed weak to `state.previewStore`. Key: `context.streamKey` (`Screens/PlaybackModels.swift:79`); when it is empty (smoke rig, Library), `PlaybackStreamKey.make(infoHash: nil, fileIdx: nil, addonId: "local", url: context.url.absoluteString, label: context.title)` (`PlaybackModels.swift:213-…`), which digests host+path and never stores link text. No disk, no sync: it goes when the controller deinits. Add a `deinit`-free release: in `destroyPlayer`, `previewStore = nil` after `mpv_terminate_destroy` (a plain property write, no weak formation).

## 3. libmpv node helper and harvest (`MPVPlayerView.swift`)

### 3.1 `commandRet` + `screenshotRaw` (libmpv helpers section, after `command` at `:2563-2573`)

The brief asked for a `commandNode(_:) -> mpv_node?` that frees the node "on return". That returns a freed node. Smallest correct alternative: a scoped reader, built on **`mpv_command_ret`** (declared in the bundled `Libmpv.framework/Headers/mpv/client.h:959`, client API 2.5), which takes the same `const char**` array `command` already builds, so no `MPV_FORMAT_NODE_ARRAY` construction is needed. (`mpv_command_node` is the equivalent if `mpv_command_ret` ever misbehaves; same free rule.)

```swift
/// eventQueue only. Runs `args`, hands the result node to `read` while it is valid, frees it.
private func withCommandResult<T>(_ args: [String], _ read: (mpv_node) -> T?) -> T? {
    guard let mpv else { return nil }
    var cargs: [UnsafePointer<CChar>?] = args.map { UnsafePointer(strdup($0)) } + [nil]
    defer { for p in cargs where p != nil { free(UnsafeMutablePointer(mutating: p!)) } }
    var result = mpv_node()
    let status = mpv_command_ret(mpv, &cargs, &result)
    guard status >= 0 else { checkError(status); return nil }
    defer { mpv_free_node_contents(&result) }
    return read(result)
}

struct MPVRawFrame { let width: Int; let height: Int; let stride: Int; let format: String; let bytes: Data }

/// eventQueue only. `screenshot-raw video bgr0`: the decoded frame, no subtitles/OSD, copied out.
private func screenshotRaw() -> MPVRawFrame? {
    withCommandResult(["screenshot-raw", "video", "bgr0"]) { node in
        guard node.format == MPV_FORMAT_NODE_MAP, let list = node.u.list else { return nil }
        var w = 0, h = 0, stride = 0, fmt = "", bytes: Data?
        for i in 0..<Int(list.pointee.num) {
            guard let k = list.pointee.keys?[i] else { continue }
            let v = list.pointee.values[i]
            switch String(cString: k) {
            case "w": w = Int(v.u.int64)
            case "h": h = Int(v.u.int64)
            case "stride": stride = Int(v.u.int64)
            case "format": if let s = v.u.string { fmt = String(cString: s) }
            case "data": if v.format == MPV_FORMAT_BYTE_ARRAY, let ba = v.u.ba, let p = ba.pointee.data {
                bytes = Data(bytes: p, count: ba.pointee.size) }
            default: break
            }
        }
        guard w > 0, h > 0, stride >= w * 4, let bytes, bytes.count >= stride * h else { return nil }
        return MPVRawFrame(width: w, height: h, stride: stride, format: fmt, bytes: bytes)
    }
}
```

If the bundled mpv rejects the third (format) argument, retry once with `["screenshot-raw", "video"]` (the default format is `bgr0`) and log it once in DEBUG.

### 3.2 `PreviewFrameScaler` (in `SeekPreviewStore.swift`, pure, off-main)

`static func makeThumbnail(_ f: MPVRawFrame, width: Int = 320) -> CGImage?`:
- bitmap info by `format`: `bgr0` → `CGImageAlphaInfo.noneSkipFirst | CGBitmapInfo.byteOrder32Little`; `bgra` → `premultipliedFirst | byteOrder32Little`; `rgba` → `premultipliedLast | byteOrder32Big`; `rgba64` or anything else → nil (logged once).
- Source `CGImage(width:height:bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: stride, space: sRGB, bitmapInfo:, provider: CGDataProvider(data: bytes as CFData), decode: nil, shouldInterpolate: false, intent: .defaultIntent)`.
- Target height `max(2, Int((Double(width) * Double(h) / Double(w)).rounded()))` (180 for 16:9, 134 for 2.39:1; the card letterboxes). `CGContext(width, height, 8, 0, sRGB, noneSkipFirst | byteOrder32Little)`, `interpolationQuality = .medium`, draw, `makeImage()`.

HDR note (UNVERIFIED): a `video` screenshot of a PQ/HLG frame may come back un-tonemapped (flat, grey). P2 accepts that; device pass item 5b checks it, and P3's decoder has the same tone-map question.

### 3.3 `HarvestScheduler` (pure, `Screens/Player/HarvestScheduler.swift`)

```swift
struct HarvestScheduler {
    var intervalSec: Double            // 10 (Auto), 5, 30; <= 0 = off
    private(set) var playedSinceLast: Double = 0
    private(set) var seekHarvestDue: TimeInterval? = nil
    private(set) var inFlight = false
    private var lastTick: TimeInterval? = nil
    /// Called from every refreshState tick. Returns true when a harvest should start now.
    mutating func tick(now: TimeInterval, playing: Bool, transportIdle: Bool, seekInFlight: Bool) -> Bool
    mutating func noteSeekLanded(now: TimeInterval)   // seekHarvestDue = now + 1.0 (a newer landing replaces it: debounce)
    mutating func noteStarted()                        // inFlight = true, playedSinceLast = 0, seekHarvestDue = nil
    mutating func noteFinished()                       // inFlight = false
}
```

`tick`: `dt = lastTick.map { min(now − $0, 1.0) } ?? 0`; `lastTick = now`. If `intervalSec <= 0` → false. "Eligible" = `playing && transportIdle && !seekInFlight && !inFlight`. While eligible, `playedSinceLast += dt` (paused, buffering, stepping, scanning, scrubbing or a seek in flight do not count: playback time, not wall clock). Return true when eligible and (`playedSinceLast >= intervalSec` or (`seekHarvestDue != nil && now >= seekHarvestDue!`)). A due seek harvest that hits a non-eligible tick waits for the next eligible one. The 1 s debounce after a landing is the "not within 1 s of a seek" rule.

Controller inputs (in `refreshState`, `:1463`, after `samplePlayClock(snap)`): `playing = fileLoaded && !snap.paused && !snap.cacheWait && !snap.coreIdle && !snap.eof && snap.videoW > 0`; `transportIdle = !transport.mode.isActive` (covers the sibling's `.scrubbing`, `TransportPreview.swift:43-45`); `seekInFlight = skipPlanner.seekInFlight != nil`. Interval read once in `viewDidLoad`: `UserDefaults.standard.integer(forKey: "debug.harvestIntervalSec")` → `0` = Auto (10), `-1` = Off, else that many seconds. (Deviation from the brief's "0 = off": an unset integer default reads 0, which must mean Auto.)

Landing hook: in `drainEvents`' `MPV_EVENT_PLAYBACK_RESTART` main block (`:2440-2466`), after the `guard generation == self.seekGeneration` line, add `self.harvest.noteSeekLanded(now: ProcessInfo.processInfo.systemUptime)`.

### 3.4 Harvest run (controller, new `// MARK: - Seek preview harvest (P2)` after `publishBuffered`, `:1617`)

```swift
private func startHarvest() {          // main
    guard let store = previewStore else { return }
    harvest.noteStarted()
    eventQueue.async { [weak self] in
        guard let self, self.mpv != nil else { DispatchQueue.main.async { [weak self] in self?.harvest.noteFinished() }; return }
        let t0 = DispatchTime.now().uptimeNanoseconds
        let sec = self.getDouble("time-pos")
        let frame = self.screenshotRaw()
        let tookMs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6
        #if DEBUG
        NSLog("[Harvest] took=%.1fms size=%dx%d fmt=%@ at=%.1f", tookMs, frame?.width ?? 0, frame?.height ?? 0, frame?.format ?? "-", sec)
        #endif
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let thumb = frame.flatMap { PreviewFrameScaler.makeThumbnail($0) }
            Task {
                if let thumb, sec.isFinite { await store.insert(thumb, at: sec) }
                let n = await store.count, bytes = await store.byteCount
                await MainActor.run { self?.harvestLanded(count: n, bytes: bytes) }
            }
        }
    }
}
```

`harvestLanded` (main): `harvest.noteFinished()`, `state.transport.previewFrames = count`, update `state.previewStoreSummary` (§3.6). The `[weak self]` captures are formed while the controller is alive (inside a block holding it strongly), never in `deinit`.

Call site: in `refreshState`, `if harvest.tick(...) { startHarvest() }`.

Cost watch: `screenshot-raw` on `vo=gpu` through MoltenVK reads the frame back at source resolution (a 4K `bgr0` frame is ~33 MB copied per harvest). The `[Harvest] took=` line is the measurement; the device pass decides whether 4K sources need a longer interval. Do not add a cap in P2.

### 3.5 Developer knob (`Screens/Settings/DeveloperSettingsPane.swift`)

`@AppStorage("debug.harvestIntervalSec") private var harvestIntervalSec = 0` beside `:119-121`; a `SettingsPickerRow` after "Exact Seek Delay (A/B)" (`:188-200`): title "Thumbnail Harvest (A/B)", options `[0, 5, 30, -1]`, labels Auto / 5 s / 30 s / Off, `descriptionID: .devHarvestInterval`.

### 3.6 Memory row

`state.previewStoreSummary = "\(n) · \(String(format: "%.1f", Double(bytes) / 1_048_576)) MB · RSS \(rssMB) MB"`, where `rssMB` is `task_vm_info.phys_footprint / 1_048_576` from `task_info(mach_task_self_, TASK_VM_INFO, …)` (a small `ProcessMemory.footprintMB()` helper in `SeekPreviewStore.swift`). `MPVPlayerPanelAdapter.rebuildInfo` (rows built at `Screens/Player/MPVPlayerPanelAdapter.swift:106-110`) appends `NativeInfoRow(label: String(localized: "Seek Previews"), value: state.previewStoreSummary)` when non-empty; add `state.$previewStoreSummary` to the Merge3 that triggers `rebuildInfo` (`:57-63`, becomes a Merge4).

## 4. Chapters

### 4.1 Read (eventQueue, on file load)

In `drainEvents`' `MPV_EVENT_FILE_LOADED` branch (`:2401-2417`), after `refreshTracksAsync()`, call `readChaptersAsync()` (it is already on `eventQueue`; call the body directly):

```swift
let raw = getString("chapter-list")          // JSON, same path P1 proved for demuxer-cache-state
var chapters = raw.map { PlayerChapters.parse(json: $0) } ?? []
if chapters.isEmpty {
    let n = getInt("chapters")               // :2582
    if n > 0 { chapters = PlayerChapters.parseIndexed(count: n,
        title: { self.getString("chapter-list/\($0)/title") },
        time: { self.getDouble("chapter-list/\($0)/time") }) }
}
#if DEBUG
NSLog("[Chapters] n=%ld raw=%@", chapters.count, String((raw ?? "nil").prefix(200)))
#endif
DispatchQueue.main.async { self.state.transport.chapters = chapters }
```

Why the JSON string: `mpv_get_property_string` on a node-typed property prints it as JSON (`demuxer-cache-state` reads as JSON on the simulator and the Apple TV, plan OUTCOME P1 Wave 1), it needs no node walker, and the indexed sub-property fallback (`chapter-list/N/title`) covers a build where the string form is the human `PRINT` form. Both run on `eventQueue`.

### 4.2 `Screens/Player/PlayerChapters.swift` (new, pure)

```swift
enum PlayerChapters {
    static func parse(json: String) -> [TransportChapter]
    static func parseIndexed(count: Int, title: (Int) -> String?, time: (Int) -> Double) -> [TransportChapter]
    static func title(at sec: Double, in chapters: [TransportChapter]) -> String?
    static func displayTitle(_ c: TransportChapter, index: Int) -> String   // empty → "Chapter %lld" (index + 1)
}
```

`parse`: top-level JSON array of objects; `time` as `NSNumber` (required, finite, ≥ 0); `title` optional string, trimmed, default `""`. Malformed JSON or a non-array → `[]`. Sort by `sec`; drop exact-duplicate times (keep first). `title(at:)`: the last chapter with `sec <= t + 0.01`; nil before the first chapter or when its title is empty.

### 4.3 Chapters tab (`Screens/Player/PlayerChaptersTab.swift`, new)

- `PlayerTopPanel.swift`: add `case chapters` to `PlayerPanelTab` (`:3-6`) with title `String(localized: "Chapters")`. Rewrite `tabs` (`:108-110`) as: `[.info, .subtitles, .audio]`, plus `.playback` when `extraTab != nil`, plus `.chapters` when `!model.chapters.isEmpty`. Add `case .chapters: PlayerChaptersTab(model: model)` to `content` (`:113-124`). The native engine never fills `chapters`, so its panel is unchanged.
- `PlayerTopPanelModel.swift`: `struct PlayerPanelChapter: Identifiable, Equatable { let id: Int; let title: String; let sec: Double; var isCurrent: Bool }`, `@Published var chapters: [PlayerPanelChapter] = []`, `var onSelectChapter: ((PlayerPanelChapter) -> Void)?`.
- `PlayerChaptersTab`: copy `PlayerSubtitlesTab`'s container (`ScrollView` + `VStack` + `.frame(maxHeight: 520)`, `Screens/Player/PlayerSubtitlesTab.swift:18-49`), a `PlayerPanelSectionCaption("Chapters")`, then one `PlayerPanelOptionRow` (`PlayerTopPanel.swift:131`) per chapter with `PlayerPanelOption(id: "\(c.id)", title: String(format: "%02d · %@ · %@", c.id + 1, c.title, TransportTimeFormat.elapsed(c.sec)), group: .audio, isSelected: c.isCurrent)`, identifier prefix `player.panel.chapter` (rows read `player.panel.chapter.0`, `.1`, …). Action: `model.onSelectChapter?(c)`.
- `MPVPlayerPanelAdapter`: subscribe to `state.transport.$chapters` and `state.$panelOpen` (rising edge); rebuild `model.chapters` from `state.transport.chapters` with `title = PlayerChapters.displayTitle`, `isCurrent` = the index `title(at: state.positionSec)` resolves to. `model.onSelectChapter = { [weak state, weak model] c in state?.seekToChapter?(c.sec); model?.onClose?() }`.
- Controller (`viewDidLoad`, next to `:361`): `state.seekToChapter = { [weak self] sec in self?.seekToChapter(sec) }`, where `seekToChapter` issues `issueSeek(kind: .user, targetSec: sec, fromSec: base, args: [String(format: "%.3f", sec), "absolute"])` with `base = skipPlanner.seekInFlight?.targetSec ?? cachedProps().position` (seekBy's rule, `:2077-2090`), calls `state.upNextCancel?()` when `sec < base`, and in DEBUG `state.seekProbe.note(commit: sec, stages: "ch")` (`Screens/Player/SeekProbe.swift`, so legs read `lastTarget`).

### 4.4 Edge click (D5)

`PlayerTuning.edgeClickModeKey = "player.edgeClickMode"` (`Screens/PlaybackModels.swift:12-31`), values `"skip10"` (default) / `"chapter"`, device-local, read once in `viewDidLoad` into `edgeClickMode`.

Pure resolver in `PlayerChapters.swift`:

```swift
enum EdgeClickMode: String { case skip10, chapter }
enum EdgeClickAction: Equatable { case relative(Double), absolute(Double) }
static func edgeClick(mode: EdgeClickMode, direction: Int, baseSec: Double,
                      chapters: [TransportChapter], skipSec: Double = 10) -> EdgeClickAction
```

Rules: `skip10`, or fewer than **2** chapters → `.relative(±skipSec)`. Chapter mode, Right: the first chapter with `sec > baseSec + 0.5` → `.absolute(sec)`; none (inside the last chapter) → `.relative(+skipSec)`. Left: the last chapter with `sec < baseSec − 3` (a 3 s grace, so a click just after a chapter start goes to the one before, as Infuse does) → `.absolute(sec)`; none → `.absolute(0)` (before or at the first chapter → start).

Wiring: P1's short click is the `.immediateSeek(deltaSec:)` output of `TransportPreview.pressBegan` (`Screens/Player/TransportPreview.swift:107`, and the scan-armed release at `:148`), performed by `apply` (`MPVPlayerView.swift:1873`) as `seekBy(d)`. Change that one case to `edgeClick(d)`:

```swift
private func edgeClick(_ d: Double) {
    let base = skipPlanner.seekInFlight?.targetSec ?? cachedProps().position
    switch PlayerChapters.edgeClick(mode: edgeClickMode, direction: d < 0 ? -1 : 1, baseSec: base,
                                    chapters: state.transport.chapters, skipSec: abs(d)) {
    case .relative(let r): seekBy(r)
    case .absolute(let t): seekToChapter(t)
    }
}
```

`TransportPreview` itself is not changed (the sibling owns it). Known, accepted consequence: a press that turns into a hold still steps from the pre-click origin, and its release commit replaces the chapter jump. That is Step behaviour unchanged; record it in the device pass.

## 5. Aspect modes

### 5.1 `Screens/Player/PlayerAspectMode.swift` (new, pure)

```swift
enum PlayerAspectMode: String, CaseIterable { case fit, fill, zoom, stretch
    var next: PlayerAspectMode            // fit → fill → zoom → stretch → fit
    var label: String                     // String(localized: "Fit"/"Fill"/"Zoom"/"Stretch")
    var mpvProps: MPVAspectProps
    var syncedName: String?               // "Fit"/"Fill"/"Zoom"; nil for stretch
    static func initial(syncedName: String?, stretchOver: String?) -> PlayerAspectMode
}
struct MPVAspectProps: Equatable { let aspectOverride: String; let panscan: Double; let videoZoom: Double; let keepAspect: Bool }
```

| mode | `video-aspect-override` | `panscan` | `video-zoom` | `keepaspect` |
|---|---|---|---|---|
| fit | `-1` | 0 | 0 | yes |
| fill | `-1` | 1.0 | 0 | yes |
| zoom | `-1` | 0 | 0.15 (log2, ≈ 1.11×, "slight zoom", tune on device) | yes |
| stretch | `-1` | 0 | 0 | no |

Every mode writes all four, so leaving any mode resets the others. `syncedName` values are the Kotlin enum names of `PlayerResizeMode { Fit, Fill, Zoom }` (`shared/src/commonMain/kotlin/com/nuvio/app/features/player/PlayerModels.kt:62-66`), read in Swift as `.name`. `initial`: when `stretchOver != nil && stretchOver == (syncedName ?? "Fit")` → `.stretch`; else the case whose `syncedName` matches; else `.fit`.

### 5.2 Application (controller)

`private func applyAspect(_ m: PlayerAspectMode)` (main): `state.transport.aspectMode = m`, then `eventQueue.async { [weak self] in guard let self, self.mpv != nil else { return }; setMpvString("video-aspect-override", p.aspectOverride); setMpvDouble("panscan", p.panscan); setMpvDouble("video-zoom", p.videoZoom); setFlag("keepaspect", p.keepAspect) }` (helpers at `:1175`, `:1337`, `:2604`). `metalLayer.contentsGravity = .resizeAspect` (`:354`) stays: the drawable covers the whole view, so mpv does all the geometry.

Initial: in `onFileLoaded()` (`:956`), after `applySubtitleStyle()`: `let synced = (PlayerSettingsRepository.shared.uiState.value_ as? PlayerSettingsUiState)?.resizeMode.name` (the settings are loaded by then, `setupMpv` calls `ensureLoaded`), `applyAspect(.initial(syncedName: synced, stretchOver: UserDefaults.standard.string(forKey: PlayerTuning.aspectStretchOverKey)))`.

### 5.3 Cycle, persistence, flash

`PlayerTuning.aspectStretchOverKey = "player.aspectStretchLast"` (String, device-local): holds the synced name that was current when the viewer picked Stretch, so a later change on the phone wins over a stale Stretch.

`cycleAspect()` (main): `let m = state.transport.aspectMode.next`; `applyAspect(m)`; persistence: if `let name = m.syncedName` → `PlayerSettingsRepository.shared.setResizeMode(mode: <PlayerResizeMode matching name>)` (`shared/.../PlayerSettingsRepository.kt:413-419`; it is synced through `resize_mode` in `PlayerSettingsStorage.apple.kt:23,100`) and `removeObject(forKey: aspectStretchOverKey)`; if `.stretch` → store the current synced name (default `"Fit"`) under that key and leave the synced value alone. No `SettingsViewModel` setter is needed: the pill is the only writer, the same direct-repository pattern `SettingsViewModel.setPauseOverlayEnabled` uses (`Screens/SettingsViewModel.swift:370-372`). No separate Settings row in P2: the phone's synced value is the default, the pill changes it.

Flash: `state.transport.aspectFlash = m.label`, cancel/re-arm a 2 s `DispatchWorkItem` that sets it nil. New `PlayerAspectFlash` view (in `PlayerAspectMode.swift`): centred `Text(label)` in `Theme.Font.sectionTitle`, horizontal padding 40 / vertical 18, `.glassEffect(.regular.tint(PlayerChipStyle.glassTint), in: Capsule())`, `.transition(.opacity)`, identifier `player.aspect.flash`. Insert in `MPVPlayerScreen`'s ZStack after `SeekProbeLabel` (`MPVPlayerView.swift:2760`): `if let text = state.transport.aspectFlash { PlayerAspectFlash(text: text).frame(maxWidth: .infinity, maxHeight: .infinity) }` with `.animation(.easeInOut(duration: 0.2), value: state.transport.aspectFlash)`. `PlayerChipStyle.swift` has no flash style today, so the view is new.

### 5.4 Aspect pill

- `PillKind` (`TransportBarModel.swift:7`): add `aspect` after `speed`. `PillKind.visible` (`Screens/Player/PlayerPills.swift:4-11`): `[.subtitles, .audio, .speed, .aspect]`, then sources, episodes, more. `symbol` `"aspectratio"`, `title` `String(localized: "Aspect")`, `panelTab` `.playback` (unused).
- `activatePill` (`MPVPlayerView.swift:2190-2196`): first line `if pill == .aspect { cycleAspect(); flashControls(); return }`. Focus stays on the pill so repeated Select keeps cycling.
- Update `NuvioTVTests/PlayerTransportBarLayoutTests.swift:113-118` (all three `visible` expectations gain `.aspect` after `.speed`). The UI leg's `pills >= 4` (`NuvioTVUITests/PlayerTransportUITests.swift:193`) still holds; the smoke rig shows 6 pills.

## 6. Settings rows and strings

- `Screens/SettingsViewModel.swift` beside `:469` / `:495`: `@Published var edgeClickMode: String = UserDefaults.standard.string(forKey: PlayerTuning.edgeClickModeKey) ?? "skip10"` and `func setEdgeClickMode(_ value: String)` writing the key.
- `Screens/Settings/PlayerSettingsPane.swift`, after "Hold Left/Right" (`:54-60`): `SettingsPickerRow(title: "Left/Right Click", selection: Binding(get: { model.edgeClickMode }, set: { model.setEdgeClickMode($0) }), options: ["skip10", "chapter"], descriptionID: .playerEdgeClick, label: { $0 == "chapter" ? "Previous/Next Chapter" : "Skip 10 s" })` (all `String(localized:)`).
- `Screens/Settings/SettingsDescriptions.swift`: cases `playerEdgeClick = "player.edgeClick"` (after `:134`) and `devHarvestInterval = "dev.harvestInterval"` (after `:201`). Texts (after `:386` / `:389`):
  - playerEdgeClick: "Choose what a single click on Left or Right does in the mpv player. Skip 10 s jumps ten seconds. Previous/Next Chapter jumps to the start of the next or previous chapter when the video has chapters, and skips 10 seconds when it does not. Default: Skip 10 s."
  - devHarvestInterval: "An A/B switch for how often the mpv player saves a small picture of the video for the seek preview. Auto saves one every 10 seconds of playback. Off saves none."
  - Footnote list (`:413`): add both to the "Applies to the next playback." case.
- New English keys in `Localizable.xcstrings` (append as English-only entries, as P1 did; the five locales run at the end of the batch): "Left/Right Click", "Skip 10 s", "Previous/Next Chapter", "Chapters", "Chapter %lld", "Aspect", "Fit", "Fill", "Zoom", "Stretch", "Thumbnail Harvest (A/B)", "5 s", "30 s", "Off" (if absent), "Seek Previews", and the two description strings. Release notes: Left/Right Click defaults to Skip 10 s; the aspect pill writes the synced Fit/Fill/Zoom value.

## 7. Probes

- Bar probe (`Screens/Player/PlayerTransportBar.swift:358-361`): append `chapters=\(model.chapters.count) aspect=\(model.aspectMode.rawValue) frames=\(model.previewFrames)`. This is a one-line hunk in a file the scrub agent also edits; whichever agent runs second rebases onto it.
- `[Harvest] took=<ms> size=<w>x<h> fmt=<f> at=<sec>` (DEBUG, `NSLog` so it reaches `log stream`), `[Chapters] n= raw=` once per file.

## 8. Tests

Unit (`iosApp/NuvioTVTests/`, `@testable import NuvioTV`; the project uses synchronized groups, new files join the targets automatically):

- **SeekPreviewStoreTests** (fake codec: `encode` returns `Data(count: image.width * 10)`, `decode` returns a 1 × 1 `CGImage`; images made with a tiny `CGContext`): 1 insert then exact lookup hits; 2 nearest of two wins, tie goes earlier; 3 miss beyond explicit tolerance; 4 default tolerance = 10 with one entry; 5 spacing = median of 5/5/20 gaps → 5, so tolerance 5; 6 gaps > 60 s ignored by spacing; 7 tolerance clamped to 30 with sparse stamps; 8 insert within 1 s replaces (count unchanged, new data); 9 eviction drops the oldest INSERTED at maxEntries 3 even when its `sec` is largest; 10 lookups do not refresh recency; 11 maxBytes cap evicts until under; 12 coverage joins 0/10/20 and splits at 200; 13 `removeAll` empties and clears the decode cache; 14 non-finite / negative / over-wide inserts ignored.
- **HarvestSchedulerTests**: due after 10 s of eligible ticks; paused ticks do not count; a non-idle transport does not count; `noteSeekLanded` fires 1 s later, a second landing resets it; nothing while `inFlight`; interval ≤ 0 never fires; `dt` capped at 1 s after a stall.
- **ChapterListParsingTests**: the five-chapter JSON (`[{"title":"Opening","time":0},…]`) → 5 sorted; empty array; malformed string; missing title → `""` and `displayTitle` "Chapter 2"; indexed fallback; `title(at:)` before, inside, exactly on a boundary.
- **PlayerAspectModeTests**: cycle order and wrap; the four prop sets (table above); `initial` maps Fit/Fill/Zoom, unknown → fit, stretch only when `stretchOver` equals the synced name, stale stretch ignored; `syncedName` nil for stretch.
- **EdgeClickModeTests** (chapters at 0/90/240/390/540): skip10 → ±10; chapter Right at 100 → 240; at 545 (last chapter) → +10 relative; Left at 100 → 90 (97 > 90); Left at 92 → 0 (90 is inside the 3 s grace, nothing earlier but 0); Left at 50 → 0; one chapter → ±10; empty → ±10.

UI legs (append to `NuvioTVUITests/PlayerTransportUITests.swift`, reuse `launch(extra:)` at `:12-32`, which already passes `-player.bufferMB 8 -debug.mpvSmokeStartOver YES`; chapter legs read `PLAYER_SMOKE_CHAPTERS_URL`, skip when unset):

Fixture (already present in the clone's `iosApp/build/smoke/` from 10-07; rebuild with): `printf ';FFMETADATA1\n…' > chapters.txt` (five chapters: Opening 0, Act One 90, Act Two 240, Act Three 390, Credits 540, `TIMEBASE=1/1000`, ends at the next start, last ends 600000), then `~/bin/ffmpeg -i test-long.mkv -i chapters.txt -map 0 -map_metadata 1 -map_chapters 1 -c copy test-long-chapters.mkv`; check with `~/bin/ffprobe -v error -show_chapters -of compact test-long-chapters.mkv` (5 lines).

1. `testChapterTicksProbe`: bar probe reads `chapters=5`.
2. `testChaptersTabSeeks`: Down opens the panel; Right ×4 to `player.panel.tab.chapters` (info, subtitles, audio, playback, chapters); Down; Down ×2 to `player.panel.chapter.2`; Select; seek probe `lastTarget` = 240 and the panel is gone.
3. `testEdgeClickChapterMode`: extra `-player.edgeClickMode chapter`; at pos < 90, one Right click; `lastTarget` = 90 and `pos` ≥ 89 within 5 s.
4. `testAspectPillCycles`: Up, Up (pill:subtitles), Right ×3 (pill:aspect), Select → `aspect=fill` and `player.aspect.flash` exists, gone after 3 s; Select ×3 → `aspect=fit`. Note the leg writes the synced value: reset with a final cycle back to fit (the last Select ×3 does that).
5. `testHarvestGrows`: plain smoke URL, wait 25 s of play (no input), bar probe `frames>=2` (raise the bar with Up to read the probe).

Gates: Debug + Release sim build; NuvioTVTests (all five new classes plus `PlayerTransportBarLayoutTests`); legs 1–5 plus P1's ten legs not regressed.

## 9. Device pass additions (Test profile)

5a. After 2 minutes of play, scrub back: frames show in the card; `[Harvest] took=` lines on 1080p and 4K sources (record both; if 4K is over ~60 ms or frames drop at each harvest, raise the 4K interval). 5b. HDR title: is the harvested frame flat? 6. Chapters MKV: ticks, Chapters tab, Left/Right Click = chapter seeks; a hold after a click still steps. 7. Aspect pill: Fit → Fill → Zoom → Stretch, flash 2 s; the phone's synced value is the start value; Stretch survives a relaunch only while the phone value is unchanged. 8. Info → Seek Previews row: ≤ 10 MB growth over 20 minutes.

## 10. Agent brief

Common: clone `~/Claude/Projects/NuvioMobile-player`, branch `claude/player-p2` (exists, off `0c10ca4a4`). MPVKit is a symlink over the gitlink: stage by explicit paths, never `git add -A`; ignore `git status` errors on MPVKit. One build at a time. Commands from `~/Claude/Projects/NuvioMobile-player/iosApp`, Bash sandbox OFF for `xcodebuild test`. Simulator `FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E`.
- Build: `xcodebuild -project iosApp.xcodeproj -scheme NuvioTV -configuration Debug -destination 'platform=tvOS Simulator,id=FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E' -derivedDataPath build/DerivedData build`.
- Unit: `xcodebuild test -project iosApp.xcodeproj -scheme NuvioTVTests -destination '<same>' -derivedDataPath build/DerivedData -only-testing:NuvioTVTests/<Class>`.
- Smoke server: `cd build/smoke && python3 range_server.py 8000 .` (background). URLs: `http://127.0.0.1:8000/test-long.mkv`, `http://127.0.0.1:8000/test-long-chapters.mkv`.
- UI: `TEST_RUNNER_PLAYER_BAR_PROBE=1 TEST_RUNNER_PLAYER_SMOKE_URL=http://127.0.0.1:8000/test-long.mkv TEST_RUNNER_PLAYER_SMOKE_CHAPTERS_URL=http://127.0.0.1:8000/test-long-chapters.mkv xcodebuild test -project iosApp.xcodeproj -scheme NuvioTVUITests -destination '<same>' -derivedDataPath build/DerivedDataUITests -only-testing:NuvioTVUITests/PlayerTransportUITests/<test>`. The sim wedges after ~6 UI runs: `xcrun simctl shutdown`/`boot` the UDID.
- Report: commit SHAs, files touched, build result, each test class count, each UI leg PASS/FAIL/SKIP with the probe line read, `[Harvest] took=` values from the sim, and every spec line not followed as written with what was done instead.

Ownership against the scrub spec (its agent A runs first, these two after it, sequentially):

- **Agent B (store + harvest).** Create `Screens/Player/SeekPreviewStore.swift` (§2, §3.2, `ProcessMemory`), `Screens/Player/HarvestScheduler.swift`, `NuvioTVTests/SeekPreviewStoreTests.swift`, `NuvioTVTests/HarvestSchedulerTests.swift`. Edit `MPVPlayerView.swift` only in: state fields `previewStore`/`previewStoreSummary`, controller `previewStore`/`harvest` properties, `viewDidLoad` store creation, `refreshState` tick, the PLAYBACK_RESTART landing hook, the harvest MARK section, the two helpers in §3.1, `destroyPlayer`'s `previewStore = nil`; `TransportBarModel.swift` (`previewFrames`); `MPVPlayerPanelAdapter.swift` (§3.6); `DeveloperSettingsPane.swift` + `SettingsDescriptions.swift` (`devHarvestInterval`); the probe's `frames=` field; strings for its rows. Leg 5.
- **Agent C (chapters + aspect + settings).** Create `Screens/Player/PlayerChapters.swift`, `Screens/Player/PlayerChaptersTab.swift`, `Screens/Player/PlayerAspectMode.swift`, `NuvioTVTests/ChapterListParsingTests.swift`, `PlayerAspectModeTests.swift`, `EdgeClickModeTests.swift`. Edit `MPVPlayerView.swift` only in: the FILE_LOADED chapter read, `viewDidLoad` (`seekToChapter` closure, `edgeClickMode` read), `apply`'s `.immediateSeek` case + `edgeClick`/`seekToChapter`, `onFileLoaded` aspect, `cycleAspect`/`applyAspect`, `activatePill`'s aspect line, the flash in `MPVPlayerScreen`; `TransportBarModel.swift` (`aspectMode`, `aspectFlash`, `chapterTitle`, `PillKind.aspect`); `PlayerPills.swift`; `PlayerTopPanel.swift`; `PlayerTopPanelModel.swift`; `MPVPlayerPanelAdapter.swift` (chapters only); `PlaybackModels.swift` (two keys); `SettingsViewModel.swift`; `PlayerSettingsPane.swift`; `SettingsDescriptions.swift` (`playerEdgeClick`); `PlayerTransportBarLayoutTests.swift`; the probe's `chapters=`/`aspect=` fields; strings. Legs 1–4, then the Release build (`-configuration Release`).
- Neither agent touches `TransportPreview.swift`, `ScrubGestureArbiter.swift`, the preview card in `PlayerTransportBar.swift`, or the pan recogniser.
