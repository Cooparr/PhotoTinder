import Photos
import SwiftData
import SwiftUI
import UIKit

struct PendingDeleteReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let identifiers: [String]

    @State private var assets: [PHAsset] = []
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        AssetThumbnail(asset: asset)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Delete \(assets.count) photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .destructive) {
                        Task { await confirmDelete() }
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete")
                        }
                    }
                    .disabled(isDeleting || assets.isEmpty)
                }
            }
            .alert(
                "Couldn't delete",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task { loadAssets() }
    }

    private func loadAssets() {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var loaded: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            loaded.append(asset)
        }
        assets = loaded
    }

    private func confirmDelete() async {
        isDeleting = true
        let capturedAssets = assets
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(capturedAssets as NSFastEnumeration)
            }
            let store = DecisionStore(context: modelContext)
            for asset in capturedAssets {
                store.record(localIdentifier: asset.localIdentifier, decision: .deleted)
            }
            dismiss()
        } catch let phError as PHPhotosError where phError.code == .userCancelled {
            isDeleting = false
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }
}

private struct AssetThumbnail: View {
    let asset: PHAsset
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.displayScale) private var displayScale

    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray6))
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .task(id: asset.localIdentifier) {
                let size = CGSize(
                    width: 200 * displayScale,
                    height: 200 * displayScale
                )
                image = await photoLibrary.requestImage(for: asset, targetSize: size)
            }
    }
}
