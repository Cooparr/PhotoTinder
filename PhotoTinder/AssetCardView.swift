import Photos
import SwiftUI
import UIKit

struct AssetCardView: View {
    let asset: PHAsset

    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.displayScale) private var displayScale

    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(.systemGray6))
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 8)
            .task(id: asset.localIdentifier) {
                image = nil
                let size = CGSize(
                    width: 1000 * displayScale,
                    height: 1500 * displayScale
                )
                image = await photoLibrary.requestImage(for: asset, targetSize: size)
            }
    }
}
