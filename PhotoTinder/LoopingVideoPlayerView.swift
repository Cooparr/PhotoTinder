import AVFoundation
import Photos
import SwiftUI
import UIKit

struct LoopingVideoPlayerView: UIViewRepresentable {
    let asset: PHAsset
    var muted: Bool = true
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    var onLoad: ((URL?) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.setVideoGravity(videoGravity)
        context.coordinator.load(
            for: asset,
            into: view,
            muted: muted,
            onLoad: onLoad
        )
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.setVideoGravity(videoGravity)
        context.coordinator.setMuted(muted)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator {
        private var player: AVPlayer?
        private var loopObserver: NSObjectProtocol?

        func load(
            for asset: PHAsset,
            into view: PlayerContainerView,
            muted: Bool,
            onLoad: ((URL?) -> Void)?
        ) {
            let options = PHVideoRequestOptions()
            options.deliveryMode = .automatic
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { [weak self, weak view] item, _ in
                guard let self, let view, let item else { return }
                DispatchQueue.main.async {
                    guard self.player == nil else { return }
                    let player = AVPlayer(playerItem: item)
                    player.isMuted = muted
                    player.actionAtItemEnd = .none
                    self.player = player
                    view.setPlayer(player)
                    player.play()
                    self.loopObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: item,
                        queue: .main
                    ) { [weak player] _ in
                        player?.seek(to: .zero)
                        player?.play()
                    }
                    let url = (item.asset as? AVURLAsset)?.url
                    onLoad?(url)
                }
            }
        }

        func setMuted(_ muted: Bool) {
            player?.isMuted = muted
        }

        func teardown() {
            player?.pause()
            if let loopObserver {
                NotificationCenter.default.removeObserver(loopObserver)
            }
            player = nil
            loopObserver = nil
        }
    }
}

final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func setPlayer(_ player: AVPlayer) {
        playerLayer.player = player
    }

    func setVideoGravity(_ gravity: AVLayerVideoGravity) {
        playerLayer.videoGravity = gravity
    }
}
