// Template for a tvOS `actual`. Goes in shared/src/tvosMain/kotlin (or wherever the
// matching `expect` lives once relocated). The repo declares in Platform.kt:
//
//     expect fun getPlatform(): Platform
//     internal expect val isIos: Boolean
//
// Mirror the iosMain implementation. Most of the ~73 expect/actual pairs in this
// codebase are Darwin APIs (NSUserDefaults, NSFileManager, NSBundle, CommonCrypto)
// that are identical on iOS and tvOS — so the bulk of them should live in a shared
// `appleMain` source set, and ONLY the few that branch on iOS-only UIKit/AVAudioSession
// need a tvOS-specific override like this one.

package com.nuvio.app

import platform.UIKit.UIDevice

class TvOSPlatform : Platform {
    override val name: String =
        UIDevice.currentDevice.systemName() + " " + UIDevice.currentDevice.systemVersion
}

actual fun getPlatform(): Platform = TvOSPlatform()

// `isIos` gates iOS-only behaviors (orientation lock, certain player paths). On tvOS we
// want those branches OFF, so return false and let tvOS-specific code handle the rest.
internal actual val isIos: Boolean = false

// TIP: grep the codebase for `isIos` before flipping this — any branch that means
// "Apple platform" rather than "iPhone specifically" may need its own `isApple` flag.
