import AVKit
import Photos
import SwiftUI
import UIKit

struct FullScreenPreviewView: View {
    let asset: PHAsset
    let onDismiss: () -> Void

    @Environment(PhotoLibraryService.self) private var photoLibrary

    @State private var image: UIImage?
    @State private var player: AVPlayer?

    @State private var scale: CGFloat = 1
    @State private var accumulatedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var dismissOffset: CGSize = .zero

    private let maxScale: CGFloat = 5

    var body: some View {
        ZStack {
            backdrop
            content
                .scaleEffect(scale)
                .offset(
                    x: offset.width,
                    y: offset.height + dismissOffset.height
                )
                .gesture(dragGesture)
                .simultaneousGesture(pinchGesture)
                .onTapGesture(count: 2) { toggleZoom() }
            overlayControls
        }
        .task { await loadContent() }
        .onDisappear { player?.pause() }
    }

    private var backdrop: some View {
        Color.black
            .ignoresSafeArea()
            .opacity(1 - min(abs(dismissOffset.height) / 300.0, 0.5))
    }

    @ViewBuilder
    private var content: some View {
        if asset.mediaType == .video, let player {
            VideoPlayer(player: player)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var videoAspectRatio: CGFloat {
        guard asset.pixelHeight > 0 else { return 9.0 / 16.0 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    private var overlayControls: some View {
        VStack {
            HStack {
                dismissButton
                Spacer()
                if asset.mediaType == .image {
                    shareButton
                }
            }
            .padding()
            Spacer()
            if asset.mediaType == .video {
                HStack {
                    Spacer()
                    shareButton
                }
                .padding()
            }
        }
    }

    private var dismissButton: some View {
        Button {
            onDismiss()
        } label: {
            controlIcon("xmark")
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if asset.mediaType == .image, let image {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview("Photo", image: Image(uiImage: image))
            ) {
                controlIcon("square.and.arrow.up")
            }
        } else if asset.mediaType == .video,
                  let url = (player?.currentItem?.asset as? AVURLAsset)?.url {
            ShareLink(item: url) {
                controlIcon("square.and.arrow.up")
            }
        }
    }

    private func controlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(10)
            .background(.ultraThinMaterial, in: Circle())
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = max(1, accumulatedScale * value.magnification)
            }
            .onEnded { _ in
                withAnimation(.spring) {
                    accumulatedScale = min(max(scale, 1), maxScale)
                    scale = accumulatedScale
                    if accumulatedScale == 1 {
                        offset = .zero
                        accumulatedOffset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: accumulatedOffset.width + value.translation.width,
                        height: accumulatedOffset.height + value.translation.height
                    )
                } else if value.translation.height > 0 {
                    dismissOffset = value.translation
                }
            }
            .onEnded { value in
                if scale > 1 {
                    accumulatedOffset = offset
                } else if value.translation.height > 150 {
                    onDismiss()
                } else {
                    withAnimation(.spring) {
                        dismissOffset = .zero
                    }
                }
            }
    }

    private func toggleZoom() {
        withAnimation(.spring) {
            if scale > 1 {
                scale = 1
                accumulatedScale = 1
                offset = .zero
                accumulatedOffset = .zero
            } else {
                scale = 2
                accumulatedScale = 2
            }
        }
    }

    private func loadContent() async {
        if asset.mediaType == .video {
            await loadVideo()
        } else {
            await loadImage()
        }
    }

    private func loadImage() async {
        image = await photoLibrary.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize
        )
    }

    private func loadVideo() async {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        let avAsset: AVAsset? = await withCheckedContinuation { continuation in
            let gate = PreviewResumeGate()
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if gate.take() {
                    continuation.resume(returning: avAsset)
                }
            }
        }

        if let avAsset {
            let item = AVPlayerItem(asset: avAsset)
            player = AVPlayer(playerItem: item)
        }
    }
}

private final class PreviewResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var taken = false
    func take() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if taken { return false }
        taken = true
        return true
    }
}
