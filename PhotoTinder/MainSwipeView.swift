import Photos
import SwiftData
import SwiftUI
import UIKit

struct MainSwipeView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(SessionState.self) private var sessionState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @Query private var allDecisions: [AssetDecision]

    @State private var assets: [PHAsset] = []
    @State private var totalLibraryCount: Int = 0
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var crossedThreshold: Bool = false
    @State private var hasLoaded: Bool = false
    @State private var previewedAsset: PreviewedAsset?
    @State private var outgoingCards: [OutgoingCard] = []
    @State private var filter: MediaFilter = .all
    @State private var sort: SwipeSort = .newestFirst
    @State private var showingFilterSheet: Bool = false

    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true

    private var reviewedCount: Int {
        max(0, totalLibraryCount - assets.count + currentIndex)
    }

    private var progress: Double {
        guard totalLibraryCount > 0 else { return 0 }
        return Double(reviewedCount) / Double(totalLibraryCount)
    }

    private var hasCards: Bool {
        currentIndex < assets.count
    }

    private var visibleCards: [PHAsset] {
        let end = min(currentIndex + 3, assets.count)
        return Array(assets[currentIndex..<end])
    }

    private let commitThreshold: CGFloat = 80

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
        .safeAreaInset(edge: .top) {
            if photoLibrary.authState == .limited {
                limitedAccessBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .task {
            guard !hasLoaded else { return }
            await loadInitial()
        }
        .onAppear { refreshTotalCount() }
        .onChange(of: scenePhase) { _, new in
            if new == .active { refreshTotalCount() }
        }
        .onChange(of: filter) { _, _ in applyFilterChange() }
        .onChange(of: sort) { _, _ in applyFilterChange() }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheetView(filter: $filter, sort: $sort)
        }
        .fullScreenCover(item: $previewedAsset) { item in
            FullScreenPreviewView(asset: item.asset) {
                previewedAsset = nil
            }
            .environment(photoLibrary)
        }
    }

    private var limitedAccessBanner: some View {
        Button {
            if let url = URL(string: "app-settings:") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Limited photo access")
                        .font(.footnote.weight(.semibold))
                    Text("Some photos are hidden. Tap to change in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.orange.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }


    private var header: some View {
        ZStack {
            counterText
            HStack {
                Spacer()
                filterButton
            }
        }
        .padding(.horizontal, 16)
    }

    private var filterButton: some View {
        Button {
            showingFilterSheet = true
        } label: {
            Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.title2)
                .foregroundStyle(.tint)
        }
        .accessibilityLabel("Filter and sort")
    }

    private var isFilterActive: Bool {
        filter != .all || sort != .newestFirst
    }

    @ViewBuilder
    private var counterText: some View {
        if !hasLoaded {
            Text("Loading library…").foregroundStyle(.secondary)
        } else if totalLibraryCount == 0 {
            Text("No photos found").foregroundStyle(.secondary)
        } else {
            VStack(spacing: 4) {
                Text("\(reviewedCount.formatted())/\(totalLibraryCount.formatted())")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(value: progress)
                    .frame(width: 160)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 32) {
            decisionButton(systemImage: "xmark", tint: .red, accessibility: "Delete") {
                commit(direction: .delete)
            }
            .disabled(!hasCards)

            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, height: 52)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .buttonStyle(BounceButtonStyle())
            .disabled(sessionState.isEmpty)
            .accessibilityLabel("Undo")

            decisionButton(systemImage: "checkmark", tint: .green, accessibility: "Keep") {
                commit(direction: .keep)
            }
            .disabled(!hasCards)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private func decisionButton(
        systemImage: String,
        tint: Color,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(tint, in: Circle())
                .shadow(color: tint.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityLabel(accessibility)
    }

    @ViewBuilder
    private var cardStack: some View {
        ZStack {
            if hasCards {
                ForEach(Array(visibleCards.enumerated()), id: \.element.localIdentifier) { pair in
                    cardView(for: pair.element, depth: pair.offset)
                        .zIndex(Double(-pair.offset))
                }
            } else if hasLoaded && outgoingCards.isEmpty {
                caughtUpState
            }

            ForEach(outgoingCards) { out in
                outgoingCardBody(for: out)
                    .rotationEffect(.degrees(out.rotation))
                    .offset(out.offset)
                    .zIndex(100)
                    .allowsHitTesting(false)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: crossedThreshold) { old, new in
            hapticsEnabled && !old && new
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: currentIndex) { _, _ in
            hapticsEnabled
        }
    }

    private func outgoingCardBody(for card: OutgoingCard) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(.systemGray6))
            .overlay {
                if let image = card.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 8)
    }

    private func cardView(for asset: PHAsset, depth: Int) -> some View {
        let isTop = depth == 0
        return AssetCardView(asset: asset, isTop: isTop)
            .overlay(alignment: .center) {
                if isTop { decisionOverlay }
            }
            .rotationEffect(.degrees(isTop ? rotationDegrees : 0))
            .offset(
                x: isTop ? dragOffset.width : 0,
                y: isTop ? dragOffset.height : 0
            )
            .onTapGesture {
                if isTop {
                    previewedAsset = PreviewedAsset(asset: asset)
                }
            }
            .gesture(dragGesture)
            .allowsHitTesting(isTop)
    }

    private var caughtUpState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("You're all caught up")
                .font(.title.bold())
            Text(totalLibraryCount == 0
                 ? "There are no photos in your library yet."
                 : "You've reviewed every photo in your library. Come back after taking more.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            let symbol = isKeep ? "checkmark.circle.fill" : "xmark.circle.fill"
            let color: Color = isKeep ? .green : .red
            Image(systemName: symbol)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, color)
                .font(.system(size: 90, weight: .bold))
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
        guard currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        let decision: DecisionKind = direction == .keep ? .kept : .pendingDelete
        decisionStore.record(localIdentifier: asset.localIdentifier, decision: decision)
        sessionState.append(asset.localIdentifier)

        let capturedOffset = dragOffset
        let capturedRotation = rotationDegrees
        let card = OutgoingCard(
            asset: asset,
            offset: capturedOffset,
            rotation: capturedRotation,
            image: photoLibrary.cachedImage(for: asset.localIdentifier)
        )
        outgoingCards.append(card)
        currentIndex += 1
        dragOffset = .zero
        crossedThreshold = false

        let offX: CGFloat = direction == .keep ? 800 : -800
        let targetRotation: Double = direction == .keep ? 18 : -18
        let capturedId = card.id

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                if let idx = outgoingCards.firstIndex(where: { $0.id == capturedId }) {
                    outgoingCards[idx].offset = CGSize(width: offX, height: capturedOffset.height + 40)
                    outgoingCards[idx].rotation = targetRotation
                }
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            outgoingCards.removeAll { $0.id == capturedId }
        }
    }

    private func undo() {
        guard let lastId = sessionState.popLast(),
              currentIndex > 0
        else { return }
        decisionStore.remove(localIdentifier: lastId)
        currentIndex -= 1
        outgoingCards.removeAll()
    }

    private func refreshTotalCount() {
        guard hasLoaded else { return }
        let newTotal = photoLibrary.fetchAssets(sort: sort, filter: filter).count
        if newTotal != totalLibraryCount {
            totalLibraryCount = newTotal
        }
    }

    private func applyFilterChange() {
        hasLoaded = false
        currentIndex = 0
        outgoingCards.removeAll()
        Task { await loadInitial() }
    }

    private func loadInitial() async {
        let decided = decisionStore.decidedIdentifiers()
        let fetch = photoLibrary.fetchAssets(sort: sort, filter: filter)
        let total = fetch.count
        var existingIdentifiers: Set<String> = []
        var undecided: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            existingIdentifiers.insert(asset.localIdentifier)
            if !decided.contains(asset.localIdentifier) {
                undecided.append(asset)
            }
        }

        // Drop orphaned .pendingDelete records (PHAsset gone from library)
        // and any legacy .deleted records left over from before eager delete.
        let toRemove = allDecisions.filter { record in
            record.decision == .deleted ||
            (record.decision == .pendingDelete && !existingIdentifiers.contains(record.localIdentifier))
        }
        for record in toRemove {
            modelContext.delete(record)
        }
        if !toRemove.isEmpty {
            try? modelContext.save()
        }

        assets = undecided
        totalLibraryCount = total
        currentIndex = 0
        hasLoaded = true
    }
}

struct PreviewedAsset: Identifiable {
    let asset: PHAsset
    var id: String { asset.localIdentifier }
}

struct OutgoingCard: Identifiable {
    let asset: PHAsset
    var offset: CGSize
    var rotation: Double
    let image: UIImage?
    var id: String { asset.localIdentifier }
}

private struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    MainSwipeView()
        .environment(PhotoLibraryService())
        .environment(SessionState())
        .modelContainer(for: AssetDecision.self, inMemory: true)
}
