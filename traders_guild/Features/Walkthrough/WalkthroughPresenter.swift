//
//  WalkthroughPresenter.swift
//  traders_guild
//
//  Page state and looping clip players for the walkthrough sheet.
//

import SwiftUI
import AVFoundation
import Combine

extension Notification.Name {
    /// Posted by Settings to replay the walkthrough; handled in MainView, which
    /// closes the drawers before presenting.
    static let presentWalkthrough = Notification.Name("presentWalkthrough")
}

/// Owns which page is showing and the one looping, muted player for it.
///
/// Only the visible page has a player. A phone has a handful of hardware video decoders and
/// `AVPlayerLooper` keeps several copies of its item queued, so a player per nearby page left
/// the visible one without a decoder on device (it sat on its poster; the simulator, decoding
/// on the Mac, never showed it). Every other page shows its poster — the clip's first frame —
/// and a clip always starts from that frame, so the handover is invisible.
@MainActor
final class WalkthroughPresenter: ObservableObject {
    @Published var currentPage: WalkthroughPage = .hero
    @Published private(set) var activeClip: ActiveClip?

    struct ActiveClip {
        let page: WalkthroughPage
        let player: AVQueuePlayer
    }

    private var looper: AVPlayerLooper?
    private var isPausedForBackground = false
    #if DEBUG
    private var statusObservation: NSKeyValueObservation?
    #endif

    let pages = WalkthroughPage.allCases

    var isOnLastPage: Bool { currentPage.isLast }

    /// Index of the current page, for the dots.
    var pageIndex: Int { currentPage.rawValue }

    // MARK: - Player

    func player(for page: WalkthroughPage) -> AVQueuePlayer? {
        activeClip?.page == page ? activeClip?.player : nil
    }

    /// Plays `page`'s clip from its first frame, releasing whatever was playing first so its
    /// decoder is free. Called when the sheet appears and whenever the page changes.
    func showClip(for page: WalkthroughPage) {
        guard activeClip?.page != page else { return }
        stopClip()
        guard let url = page.clipURL() else { return }
        WalkthroughAudioPolicy.prepare()

        let player = AVQueuePlayer()
        player.isMuted = true
        player.allowsExternalPlayback = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.actionAtItemEnd = .advance
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        activeClip = ActiveClip(page: page, player: player)
        #if DEBUG
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { player, _ in
            if let error = player.currentItem?.error {
                print("🎬 walkthrough \(page.slot): \(error)")
            }
        }
        #endif
        if !isPausedForBackground {
            player.play()
        }
    }

    func pauseAll() {
        isPausedForBackground = true
        activeClip?.player.pause()
    }

    func resumeVisible() {
        isPausedForBackground = false
        activeClip?.player.play()
    }

    func tearDown() {
        stopClip()
    }

    private func stopClip() {
        #if DEBUG
        statusObservation = nil
        #endif
        looper?.disableLooping()
        looper = nil
        activeClip?.player.pause()
        activeClip?.player.removeAllItems()
        activeClip = nil
    }

    // MARK: - Navigation

    /// Moves to the next page; a no-op on the last page (its button is the CTA).
    func advance() {
        guard let next = currentPage.next else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPage = next
        }
    }
}

/// AVPlayer activates the audio session when it starts, and under the default
/// `.soloAmbient` category that silences other apps' audio even for muted,
/// audio-less clips. Switching to `.ambient` with mixing keeps the user's music
/// playing. Only done while the category is still the default:
/// `SpeechRecognitionService` sets `.playAndRecord` for itself and must not be
/// overridden, and once it has run the category is no longer `.soloAmbient`.
enum WalkthroughAudioPolicy {
    static func prepare() {
        let session = AVAudioSession.sharedInstance()
        guard session.category == .soloAmbient else { return }
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }
}
