import Photos
import SwiftUI
import UIKit

struct MainSwipeView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.displayScale) private var displayScale

    @State private var fetchResult: PHFetchResult<PHAsset>?
    @State private var currentIndex: Int = 0
    @State private var currentImage: UIImage?
    @State private var isLoadingImage: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            header
            cardView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            actionButtons
        }
        .padding(16)
        .task { await loadInitial() }
    }

    private var header: some View {
        Group {
            if let fetchResult {
                if fetchResult.count == 0 {
                    Text("No photos found").foregroundStyle(.secondary)
                } else {
                    Text("\(min(currentIndex + 1, fetchResult.count)) of \(fetchResult.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Loading library…").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var cardView: some View {
        if let currentImage {
            Image(uiImage: currentImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 10)
        } else if isLoadingImage {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gray.opacity(0.1))
                .overlay(ProgressView())
        } else {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gray.opacity(0.1))
                .overlay(Text("All caught up").foregroundStyle(.secondary))
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                logDecision("delete")
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Button {
                logDecision("keep")
            } label: {
                Label("Keep", systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .controlSize(.large)
        .disabled(currentImage == nil)
    }

    private func loadInitial() async {
        fetchResult = photoLibrary.fetchAssetsNewestFirst()
        currentIndex = 0
        await loadCurrentImage()
    }

    private func loadCurrentImage() async {
        currentImage = nil
        guard let fetchResult, currentIndex < fetchResult.count else { return }
        let asset = fetchResult.object(at: currentIndex)
        isLoadingImage = true
        let size = CGSize(width: 1200 * displayScale, height: 1800 * displayScale)
        let image = await photoLibrary.requestImage(for: asset, targetSize: size)
        isLoadingImage = false
        currentImage = image
    }

    private func logDecision(_ kind: String) {
        guard let fetchResult, currentIndex < fetchResult.count else { return }
        let asset = fetchResult.object(at: currentIndex)
        let mediaLabel = asset.mediaType == .video ? "video" : "image"
        print("[\(kind)] \(asset.localIdentifier) (\(mediaLabel))")
        currentIndex += 1
        Task { await loadCurrentImage() }
    }
}

#Preview {
    MainSwipeView()
        .environment(PhotoLibraryService())
}
