import SwiftUI
import AVKit
import SharedCore

/// tvOS playback surface. Primary path is AVPlayer/AVPlayerViewController, which gives
/// the native focus-aware transport, scrubbing UI, and HLS/DASH for free.
///
/// The stream URL + headers come straight from the shared stream-resolution logic
/// (addons → URL, debrid unlock, etc.) — only the playback surface is new on tvOS.
struct PlayerView: UIViewControllerRepresentable {
    let streamURL: URL
    let headers: [String: String]          // some addons/debrid require auth headers
    var startSeconds: Double = 0           // resume position from watch-progress

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let asset = AVURLAsset(
            url: streamURL,
            options: headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)

        if startSeconds > 0 {
            player.seek(to: CMTime(seconds: startSeconds, preferredTimescale: 600))
        }

        let vc = AVPlayerViewController()
        vc.player = player
        player.play()
        return vc
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    // Phase 2 TODO:
    //  • write watch-progress back via the shared repository on pause/exit
    //  • subtitle/audio track selection (AVMediaSelectionGroup, native first)
    //  • MPVKit fallback for codecs/subtitle formats AVPlayer can't handle
}
