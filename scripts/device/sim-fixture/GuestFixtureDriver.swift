import XCTest

/// Standalone XCUITest driver for `scripts/device/sim-fixture-rebuild.sh`. NOT part of the app's
/// Xcode project: the rebuild script compiles this one file with `swiftc` into a UI-test bundle,
/// hosts it in the platform's stock XCTRunner.app and runs it with `xcodebuild
/// test-without-building -xctestrun`, so the NuvioTV project and its UI test target stay untouched.
///
/// It drives the app (by bundle id, already installed on the simulator) through its REAL guest
/// path, the way a person with a remote would:
///   1. Welcome › "Continue as Guest"  (AuthRepository.signInAnonymously → AuthEvent.GuestChosen)
///   2. empty "Who's watching?" › "Add Profile" › name "Chris" › Save   (local guest profile)
///   3. select "Chris" › Home  (the guest's Cinemeta seed runs, Home mounts)
/// then, on a second launch, applies the Continue Watching seed passed in the environment
/// (`FIXTURE_CW_SEED_B64`, the app's own DEBUG `-debug.continueWatchingSeedJsonB64`, guest only).
///
/// Every step is state driven and idempotent: a device already past a step skips it. The driver
/// never presses Select on a tile whose focus it could not verify.
final class GuestFixtureDriver: XCTestCase {

    let remote = XCUIRemote.shared
    let bundleId = ProcessInfo.processInfo.environment["FIXTURE_BUNDLE_ID"] ?? "com.nuvio.media.NuvioTV"
    let profileName = ProcessInfo.processInfo.environment["FIXTURE_PROFILE_NAME"] ?? "Chris"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - helpers

    private func pause(_ s: TimeInterval) { Thread.sleep(forTimeInterval: s) }

    private func note(_ s: String) { print("[FixtureDriver] \(s)") }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func poll(_ timeout: TimeInterval, _ cond: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if cond() { return true }
            pause(1)
        }
        return cond()
    }

    /// Presses `dir` one step at a time until `el` reads focused (checked before each press).
    private func moveFocus(_ dir: XCUIRemote.Button, until el: XCUIElement, max: Int) -> Bool {
        for _ in 0...max {
            if el.exists, el.hasFocus { return true }
            remote.press(dir)
            pause(0.6)
        }
        return el.exists && el.hasFocus
    }

    private func focusedLabels(_ app: XCUIApplication) -> String {
        let f = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true"))
        return (0..<min(f.count, 4)).map { f.element(boundBy: $0).label }.joined(separator: " | ")
    }

    private func profileTile(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", profileName)).firstMatch
    }

    /// Selects the profile tile only once it reads focused. Returns false (nothing pressed) otherwise.
    private func selectProfile(_ app: XCUIApplication) -> Bool {
        let tile = profileTile(app)
        guard tile.waitForExistence(timeout: 30) else { return false }
        pause(1)
        guard moveFocus(.left, until: tile, max: 4) || moveFocus(.right, until: tile, max: 6) else {
            note("profile tile never read focused (focused: \(focusedLabels(app)))")
            shot("profile_unverified")
            return false
        }
        remote.press(.select)
        return true
    }

    /// Home is up once the tab bar's Settings tab (or the hero probe) is in the tree.
    private func homeIsUp(_ app: XCUIApplication) -> Bool {
        app.buttons["Settings"].exists || app.descendants(matching: .any)["debug_hero"].exists
            || app.descendants(matching: .any)["debug_stage"].exists
    }

    // MARK: - the fixture walk

    func testBuildGuestFixture() throws {
        let app = XCUIApplication(bundleIdentifier: bundleId)
        app.launchArguments = [
            "-debug.rememberLastProfile", "NO",
            "-inline_trailers_enabled", "NO",
            "-hero_trailer_autoplay", "NO",
            "-detail_trailer_autoplay", "NO",
        ]
        app.launch()

        let guest = app.buttons["Continue as Guest"]
        let addProfile = app.buttons["Add Profile"]
        XCTAssertTrue(poll(90) { guest.exists || addProfile.exists || profileTile(app).exists },
                      "neither Welcome nor the profile picker appeared")
        shot("00_landing")

        // 1. Welcome › Continue as Guest (only on a device with no guest yet).
        if guest.exists {
            note("welcome: walking to Continue as Guest")
            var focused = moveFocus(.down, until: guest, max: 6)
            if !focused { focused = moveFocus(.left, until: guest, max: 4) || moveFocus(.right, until: guest, max: 4) }
            guard focused else {
                shot("01_guest_unverified")
                XCTFail("Continue as Guest never read focused (focused: \(focusedLabels(app)))")
                return
            }
            remote.press(.select)
            note("welcome: pressed Continue as Guest")
            XCTAssertTrue(poll(60) { addProfile.exists || profileTile(app).exists },
                          "the profile picker never appeared after Continue as Guest")
            shot("01_after_guest")
        } else {
            note("welcome skipped: a guest session is already restored")
        }

        // 2. Create the profile when the picker has none by that name.
        if !profileTile(app).exists {
            note("picker: creating profile \(profileName)")
            XCTAssertTrue(addProfile.waitForExistence(timeout: 20), "no Add Profile tile")
            guard moveFocus(.left, until: addProfile, max: 4) || moveFocus(.right, until: addProfile, max: 6) else {
                shot("02_add_unverified")
                XCTFail("Add Profile never read focused (focused: \(focusedLabels(app)))")
                return
            }
            remote.press(.select)
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 20), "the profile editor's name field never appeared")
            pause(2)
            shot("02_editor")
            guard moveFocus(.up, until: field, max: 4) else {
                XCTFail("the name field never read focused (focused: \(focusedLabels(app)))")
                return
            }
            remote.press(.select) // fullscreen keyboard
            pause(2)
            app.typeText(profileName)
            pause(2)
            shot("03_named")
            // The tvOS fullscreen keyboard stays up after typing ("\n" does not close it): walk
            // Down to its "done" button and press it; Menu (which keeps the text) as a fallback.
            let done = app.buttons["done"]
            if done.exists, moveFocus(.down, until: done, max: 5) {
                remote.press(.select)
            } else {
                note("keyboard: no focusable done button, pressing Menu")
                remote.press(.menu)
            }
            pause(2)
            shot("03b_keyboard_closed")
            let save = app.buttons["Save"]
            XCTAssertTrue(save.waitForExistence(timeout: 15), "no Save button in the profile editor")
            guard moveFocus(.down, until: save, max: 10) else {
                XCTFail("Save never read focused (focused: \(focusedLabels(app)))")
                return
            }
            remote.press(.select)
            XCTAssertTrue(profileTile(app).waitForExistence(timeout: 30), "the new profile tile never appeared")
            pause(2)
            shot("04_saved")
        } else {
            note("picker: profile \(profileName) already exists")
        }

        // 3. Enter the profile; Home mounts (and seeds Cinemeta on an empty add-on store).
        if !homeIsUp(app) {
            XCTAssertTrue(selectProfile(app), "could not select the \(profileName) tile")
        }
        XCTAssertTrue(poll(60) { homeIsUp(app) }, "Home never appeared after selecting \(profileName)")
        pause(20) // Cinemeta seed + first catalog fan-out persist
        shot("05_home")
        app.terminate()

        // 4. Continue Watching seed (the app's own guest-only DEBUG seed, persisted through
        //    WatchProgressRepository.upsertPlaybackProgress).
        if let seed = ProcessInfo.processInfo.environment["FIXTURE_CW_SEED_B64"], !seed.isEmpty {
            note("continue watching: seeding")
            app.launchArguments = [
                "-debug.rememberLastProfile", "NO",
                "-inline_trailers_enabled", "NO",
                "-hero_trailer_autoplay", "NO",
                "-debug.continueWatchingSeedJsonB64", seed,
            ]
            app.launch()
            XCTAssertTrue(profileTile(app).waitForExistence(timeout: 90), "picker missing on the seed launch")
            XCTAssertTrue(selectProfile(app), "could not select the \(profileName) tile on the seed launch")
            XCTAssertTrue(poll(60) { homeIsUp(app) }, "Home never appeared on the seed launch")
            pause(20)
            shot("06_home_seeded")
            app.terminate()
        }
        note("done")
    }
}
