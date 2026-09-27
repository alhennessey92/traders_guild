//
//  WalkthroughVideoView.swift
//  traders_guild
//
//  AVPlayerLayer host and poster image for a walkthrough page.
//

import SwiftUI
import AVFoundation

#if canImport(UIKit)
import UIKit

/// A bare `AVPlayerLayer` — SwiftUI's `VideoPlayer` draws transport controls,
/// which a silent looping product clip must not have.
struct WalkthroughVideoView: UIViewRepresentable {
    let player: AVQueuePlayer
    /// Flipped once the layer has a frame to draw, so the poster underneath can
    /// fade out instead of the clip popping in over it.
    let onReadyForDisplay: (Bool) -> Void

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        // The view is given the recording's own aspect (the page crops it), so fill and fit
        // agree; fill guards against a rounding-point sliver. See `WalkthroughPage.clipPlacement`.
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        view.onReadyForDisplayChange = { ready in
            context.coordinator.onReadyForDisplay(ready)
        }
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        context.coordinator.onReadyForDisplay = onReadyForDisplay
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onReadyForDisplay: onReadyForDisplay)
    }

    final class Coordinator {
        var onReadyForDisplay: (Bool) -> Void
        init(onReadyForDisplay: @escaping (Bool) -> Void) {
            self.onReadyForDisplay = onReadyForDisplay
        }
    }

    final class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        var onReadyForDisplayChange: ((Bool) -> Void)? {
            didSet { observeReadiness() }
        }

        private var readinessObservation: NSKeyValueObservation?

        private func observeReadiness() {
            readinessObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
                let ready = layer.isReadyForDisplay
                DispatchQueue.main.async {
                    self?.onReadyForDisplayChange?(ready)
                }
            }
        }
    }
}

/// The page's first frame, shown until the clip is ready and whenever Reduce
/// Motion is on or a slot has no clip yet.
struct WalkthroughPosterImage: View {
    let url: URL?

    var body: some View {
        if let url, let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle().fill(AppColors.whiteText.opacity(0.05))
        }
    }
}

#else

/// The downstream macOS branch has no player host yet; pages show posters.
struct WalkthroughPosterImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(AppColors.whiteText.opacity(0.05))
        }
    }
}

#endif
