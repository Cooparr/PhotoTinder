import Photos
import SwiftUI
import UIKit

struct AssetCardView: View {
    let asset: PHAsset
    var isTop: Bool = false

    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.displayScale) private var displayScale

    @State private var image: UIImage?

    private var isVideo: Bool {
        asset.mediaType == .video
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(.systemGray6))
            .overlay {
                if isVideo && isTop {
                    ZStack {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                        LoopingVideoPlayerView(asset: asset)
                    }
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .overlay(alignment: .topLeading) {
                if isVideo {
                    videoBadge
                        .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 8)
            .onChange(of: asset.localIdentifier, initial: true) {
                image = photoLibrary.cachedImage(for: asset.localIdentifier)
            }
            .task(id: asset.localIdentifier) {
                let size = CGSize(
                    width: 1000 * displayScale,
                    height: 1500 * displayScale
                )
                let loaded = await photoLibrary.requestImage(for: asset, targetSize: size)
                if !Task.isCancelled, let loaded {
                    image = loaded
                }
            }
    }

    private var videoBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .bold))
            Text(formatDuration(asset.duration))
                .font(.caption2.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55), in: Capsule())
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
