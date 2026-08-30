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
    @State private var livePhotoReplayTrigger: Int = 0

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
                .allowsHitTesting(false)
            if isLivePhoto {
                Color.clear
                    .aspectRatio(mediaAspectRatio, contentMode: .fit)
                    .overlay(alignment: .topLeading) {
                        liveBadge.padding(12)
                    }
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            PreviewGestureLayer(
                onPinchPan: handlePinchPan,
                onDrag: handleDrag,
                onDoubleTap: toggleZoom,
                onLongPress: { livePhotoReplayTrigger += 1 }
            )
        }
        .safeAreaInset(edge: .top) { topBar }
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
                .aspectRatio(mediaAspectRatio, contentMode: .fit)
        } else if isLivePhoto {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
                LivePhotoPlayerView(
                    asset: asset,
                    contentMode: .scaleAspectFit,
                    replayTrigger: livePhotoReplayTrigger
                )
            }
            .aspectRatio(mediaAspectRatio, contentMode: .fit)
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

    private var isLivePhoto: Bool {
        asset.mediaSubtypes.contains(.photoLive)
    }

    private var mediaAspectRatio: CGFloat {
        guard asset.pixelHeight > 0 else { return 9.0 / 16.0 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "livephoto")
                .font(.system(size: 10, weight: .bold))
            Text("LIVE")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55), in: Capsule())
    }

    private var topBar: some View {
        HStack {
            dismissButton
            Spacer()
            shareButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        } else {
            controlIcon("square.and.arrow.up")
                .opacity(0)
        }
    }

    private func controlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(10)
            .background(.ultraThinMaterial, in: Circle())
    }

    private func handlePinchPan(_ update: PreviewGestureLayer.PinchPanUpdate) {
        switch update.phase {
        case .began:
            break
        case .changed:
            let target = accumulatedScale * update.scale
            let displayScale = rubberband(target, min: 1, max: maxScale)
            let ratio = displayScale / accumulatedScale
            let f = update.startCentroid
            offset = CGSize(
                width: update.translation.width + (1 - ratio) * f.x + ratio * accumulatedOffset.width,
                height: update.translation.height + (1 - ratio) * f.y + ratio * accumulatedOffset.height
            )
            scale = displayScale
        case .ended:
            let clamped = min(max(scale, 1), maxScale)
            withAnimation(.spring) {
                scale = clamped
                accumulatedScale = clamped
                if clamped == 1 {
                    offset = .zero
                }
                accumulatedOffset = offset
            }
        }
    }

    private func rubberband(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        if value < minValue {
            return minValue - (minValue - value) * 0.5
        } else if value > maxValue {
            return maxValue + (value - maxValue) * 0.5
        } else {
            return value
        }
    }

    private func handleDrag(_ update: PreviewGestureLayer.DragUpdate) {
        switch update.phase {
        case .began:
            break
        case .changed:
            if scale > 1 {
                offset = CGSize(
                    width: accumulatedOffset.width + update.translation.width,
                    height: accumulatedOffset.height + update.translation.height
                )
            } else if update.translation.height > 0 {
                dismissOffset = update.translation
            }
        case .ended:
            if scale > 1 {
                accumulatedOffset = offset
            } else if update.translation.height > 150 {
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
            let newPlayer = AVPlayer(playerItem: item)
            newPlayer.isMuted = true
            player = newPlayer
            newPlayer.play()
        }
    }
}

private struct PreviewGestureLayer: UIViewRepresentable {
    struct PinchPanUpdate {
        enum Phase { case began, changed, ended }
        let phase: Phase
        let scale: CGFloat
        let translation: CGSize
        let startCentroid: CGPoint
    }
    struct DragUpdate {
        enum Phase { case began, changed, ended }
        let phase: Phase
        let translation: CGSize
    }

    let onPinchPan: (PinchPanUpdate) -> Void
    let onDrag: (DragUpdate) -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPinchPan: onPinchPan,
            onDrag: onDrag,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinchPan(_:))
        )
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        let twoPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinchPan(_:))
        )
        twoPan.minimumNumberOfTouches = 2
        twoPan.maximumNumberOfTouches = 2
        twoPan.delegate = context.coordinator
        view.addGestureRecognizer(twoPan)

        let onePan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleOnePan(_:))
        )
        onePan.minimumNumberOfTouches = 1
        onePan.maximumNumberOfTouches = 1
        onePan.delegate = context.coordinator
        view.addGestureRecognizer(onePan)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = context.coordinator
        view.addGestureRecognizer(doubleTap)

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.3
        longPress.delegate = context.coordinator
        view.addGestureRecognizer(longPress)

        onePan.require(toFail: doubleTap)
        onePan.require(toFail: longPress)

        context.coordinator.pinch = pinch
        context.coordinator.twoPan = twoPan
        context.coordinator.onePan = onePan
        context.coordinator.hostView = view

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPinchPan = onPinchPan
        context.coordinator.onDrag = onDrag
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onLongPress = onLongPress
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPinchPan: (PinchPanUpdate) -> Void
        var onDrag: (DragUpdate) -> Void
        var onDoubleTap: () -> Void
        var onLongPress: () -> Void

        weak var pinch: UIPinchGestureRecognizer?
        weak var twoPan: UIPanGestureRecognizer?
        weak var onePan: UIPanGestureRecognizer?
        weak var hostView: UIView?

        private var pinchPanActive = false
        private var startCentroid: CGPoint = .zero

        init(
            onPinchPan: @escaping (PinchPanUpdate) -> Void,
            onDrag: @escaping (DragUpdate) -> Void,
            onDoubleTap: @escaping () -> Void,
            onLongPress: @escaping () -> Void
        ) {
            self.onPinchPan = onPinchPan
            self.onDrag = onDrag
            self.onDoubleTap = onDoubleTap
            self.onLongPress = onLongPress
        }

        // Let pinch + two-finger pan run simultaneously; keep single-finger pan
        // and double-tap separate.
        func gestureRecognizer(
            _ gr: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            let ids = Set([ObjectIdentifier(gr), ObjectIdentifier(other)])
            if let pinch, let twoPan,
               ids == Set([ObjectIdentifier(pinch), ObjectIdentifier(twoPan)]) {
                return true
            }
            return false
        }

        @objc func handlePinchPan(_ gr: UIGestureRecognizer) {
            guard let pinch, let twoPan, let hostView else { return }

            let pinchActive = pinch.state == .began || pinch.state == .changed
            let panActive = twoPan.state == .began || twoPan.state == .changed
            let anyActive = pinchActive || panActive

            if !pinchPanActive && anyActive {
                let center = CGPoint(x: hostView.bounds.midX, y: hostView.bounds.midY)
                let raw = pinchActive ? pinch.location(in: hostView) : twoPan.location(in: hostView)
                startCentroid = CGPoint(x: raw.x - center.x, y: raw.y - center.y)
                pinchPanActive = true
                onPinchPan(PinchPanUpdate(
                    phase: .began,
                    scale: 1,
                    translation: .zero,
                    startCentroid: startCentroid
                ))
            } else if pinchPanActive && anyActive {
                let translation = twoPan.translation(in: hostView)
                onPinchPan(PinchPanUpdate(
                    phase: .changed,
                    scale: pinch.scale,
                    translation: CGSize(width: translation.x, height: translation.y),
                    startCentroid: startCentroid
                ))
            } else if pinchPanActive && !anyActive {
                let translation = twoPan.translation(in: hostView)
                onPinchPan(PinchPanUpdate(
                    phase: .ended,
                    scale: pinch.scale,
                    translation: CGSize(width: translation.x, height: translation.y),
                    startCentroid: startCentroid
                ))
                pinch.scale = 1
                twoPan.setTranslation(.zero, in: hostView)
                pinchPanActive = false
            }
        }

        @objc func handleOnePan(_ gr: UIPanGestureRecognizer) {
            guard let hostView else { return }
            let translation = gr.translation(in: hostView)
            switch gr.state {
            case .began:
                onDrag(DragUpdate(phase: .began, translation: .zero))
            case .changed:
                onDrag(DragUpdate(
                    phase: .changed,
                    translation: CGSize(width: translation.x, height: translation.y)
                ))
            case .ended, .cancelled, .failed:
                onDrag(DragUpdate(
                    phase: .ended,
                    translation: CGSize(width: translation.x, height: translation.y)
                ))
            default:
                break
            }
        }

        @objc func handleDoubleTap(_ gr: UITapGestureRecognizer) {
            if gr.state == .recognized {
                onDoubleTap()
            }
        }

        @objc func handleLongPress(_ gr: UILongPressGestureRecognizer) {
            if gr.state == .began {
                onLongPress()
            }
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
