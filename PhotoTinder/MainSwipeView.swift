import Photos
import SwiftUI
import UIKit

struct MainSwipeView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary

    @State private var fetchResult: PHFetchResult<PHAsset>?
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var crossedThreshold: Bool = false

    private let commitThreshold: CGFloat = 120

    var body: some View {
        VStack(spacing: 16) {
            header
            cardStack
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 16)
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

    private var cardStack: some View {
        ZStack {
            peekCard.offset(y: 20).scaleEffect(0.88)
            peekCard.offset(y: 10).scaleEffect(0.94)
            topCard
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: crossedThreshold) { old, new in
            !old && new
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: currentIndex)
    }

    private var peekCard: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(.systemGray6))
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }

    @ViewBuilder
    private var topCard: some View {
        if let fetchResult, currentIndex < fetchResult.count {
            let asset = fetchResult.object(at: currentIndex)
            AssetCardView(asset: asset)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay(alignment: .center) { decisionOverlay }
                .rotationEffect(.degrees(rotationDegrees))
                .offset(dragOffset)
                .gesture(dragGesture)
                .id(asset.localIdentifier)
        } else if fetchResult != nil {
            allCaughtUpCard
        }
    }

    private var allCaughtUpCard: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(.systemGray6))
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("All caught up")
                        .font(.title2.bold())
                }
            }
    }

    private var rotationDegrees: Double {
        Double(dragOffset.width) / 15.0
    }

    @ViewBuilder
    private var decisionOverlay: some View {
        let x = dragOffset.width
        if x != 0 {
            let opacity = min(abs(x) / commitThreshold, 1)
            let isKeep = x > 0
            let color: Color = isKeep ? .green : .red
            let text = isKeep ? "KEEP" : "DELETE"
            Text(text)
                .font(.system(size: 60, weight: .heavy))
                .foregroundStyle(color)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: 5)
                }
                .rotationEffect(.degrees(isKeep ? -15 : 15))
                .opacity(opacity)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
                crossedThreshold = abs(value.translation.width) > commitThreshold
            }
            .onEnded { value in
                if abs(value.translation.width) > commitThreshold {
                    let direction: SwipeDirection = value.translation.width > 0 ? .keep : .delete
                    commit(direction: direction)
                } else {
                    withAnimation(.spring) {
                        dragOffset = .zero
                    }
                    crossedThreshold = false
                }
            }
    }

    private enum SwipeDirection {
        case keep, delete
    }

    private func commit(direction: SwipeDirection) {
        guard let fetchResult, currentIndex < fetchResult.count else { return }
        let asset = fetchResult.object(at: currentIndex)
        let mediaLabel = asset.mediaType == .video ? "video" : "image"
        print("[\(direction == .keep ? "keep" : "delete")] \(asset.localIdentifier) (\(mediaLabel))")

        let offX: CGFloat = direction == .keep ? 1000 : -1000
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: offX, height: dragOffset.height)
        }

        Task {
            try? await Task.sleep(for: .milliseconds(250))
            currentIndex += 1
            dragOffset = .zero
            crossedThreshold = false
        }
    }

    private func loadInitial() async {
        fetchResult = photoLibrary.fetchAssetsNewestFirst()
        currentIndex = 0
    }
}

#Preview {
    MainSwipeView()
        .environment(PhotoLibraryService())
}
