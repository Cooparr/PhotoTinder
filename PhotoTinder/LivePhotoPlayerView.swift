import Photos
import PhotosUI
import SwiftUI
import UIKit

struct LivePhotoPlayerView: UIViewRepresentable {
    let asset: PHAsset

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        context.coordinator.load(for: asset, into: view)
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {}

    static func dismantleUIView(_ uiView: PHLivePhotoView, coordinator: Coordinator) {
        coordinator.cancel()
        uiView.stopPlayback()
        uiView.livePhoto = nil
    }

    final class Coordinator {
        private var requestID: PHImageRequestID?

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
