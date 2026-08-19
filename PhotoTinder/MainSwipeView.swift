import Photos
import SwiftData
import SwiftUI
import UIKit

struct MainSwipeView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.modelContext) private var modelContext

    @State private var assets: [PHAsset] = []
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var crossedThreshold: Bool = false
    @State private var hasLoaded: Bool = false
    @State private var sessionUndoStack: [String] = []
    @State private var isCommitting: Bool = false

    private let commitThreshold: CGFloat = 120

    private var decisionStore: DecisionStore {
        DecisionStore(context: modelContext)
    }

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
        ZStack {
            counterText
            HStack {
                Spacer()
                undoButton
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    @ViewBuilder
    private var counterText: some View {
        if !hasLoaded {
            Text("Loading library…").foregroundStyle(.secondary)
        } else if assets.isEmpty {
            Text("Nothing left to review").foregroundStyle(.secondary)
        } else {
            Text("\(min(currentIndex + 1, assets.count)) of \(assets.count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var undoButton: some View {
        Button {
            undo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.title3)
        }
        .disabled(sessionUndoStack.isEmpty || isCommitting)
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
        if currentIndex < assets.count {
            let asset = assets[currentIndex]
            AssetCardView(asset: asset)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay(alignment: .center) { decisionOverlay }
                .rotationEffect(.degrees(rotationDegrees))
                .offset(dragOffset)
                .gesture(dragGesture)
                .id(asset.localIdentifier)
        } else if hasLoaded {
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
        guard currentIndex < assets.count, !isCommitting else { return }
        isCommitting = true
        let asset = assets[currentIndex]
        let decision: DecisionKind = direction == .keep ? .kept : .pendingDelete
        decisionStore.record(localIdentifier: asset.localIdentifier, decision: decision)
        sessionUndoStack.append(asset.localIdentifier)

        let offX: CGFloat = direction == .keep ? 1000 : -1000
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: offX, height: dragOffset.height)
        }

        Task {
            try? await Task.sleep(for: .milliseconds(250))
            currentIndex += 1
            dragOffset = .zero
            crossedThreshold = false
            isCommitting = false
        }
    }

    private func undo() {
        guard !isCommitting,
              let lastId = sessionUndoStack.popLast(),
              currentIndex > 0
        else { return }
        decisionStore.remove(localIdentifier: lastId)
        currentIndex -= 1
    }

    private func loadInitial() async {
        let decided = decisionStore.decidedIdentifiers()
        let fetch = photoLibrary.fetchAssetsNewestFirst()
        var undecided: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            if !decided.contains(asset.localIdentifier) {
                undecided.append(asset)
            }
        }
        assets = undecided
        currentIndex = 0
        hasLoaded = true
    }
}

#Preview {
    MainSwipeView()
        .environment(PhotoLibraryService())
        .modelContainer(for: AssetDecision.self, inMemory: true)
}
