import Photos
import PhotosUI
import SwiftUI
import UIKit

struct LivePhotoPlayerView: UIViewRepresentable {
    let asset: PHAsset
    var contentMode: UIView.ContentMode = .scaleAspectFill
    var replayTrigger: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator(lastTrigger: replayTrigger) }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = contentMode
        view.clipsToBounds = true
        context.coordinator.load(for: asset, into: view)
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.contentMode = contentMode
        if replayTrigger != context.coordinator.lastTrigger {
            context.coordinator.lastTrigger = replayTrigger
            uiView.startPlayback(with: .full)
        }
    }

    static func dismantleUIView(_ uiView: PHLivePhotoView, coordinator: Coordinator) {
        coordinator.cancel()
        uiView.stopPlayback()
        uiView.livePhoto = nil
    }

    final class Coordinator {
        var lastTrigger: Int
        private var requestID: PHImageRequestID?

        init(lastTrigger: Int) {
            self.lastTrigger = lastTrigger
        }

        func load(for asset: PHAsset, into view: PHLivePhotoView) {
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            requestID = PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak view] livePhoto, _ in
                guard let view, let livePhoto else { return }
                DispatchQueue.main.async {
                    view.livePhoto = livePhoto
                    view.startPlayback(with: .full)
                }
            }
        }

        func cancel() {
            if let id = requestID {
                PHImageManager.default().cancelImageRequest(id)
            }
            requestID = nil
        }
    }
}
