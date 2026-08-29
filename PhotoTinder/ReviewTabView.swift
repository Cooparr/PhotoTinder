import Photos
import SwiftData
import SwiftUI
import UIKit

struct ReviewTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    @Query private var allDecisions: [AssetDecision]

    @State private var isDeleting: Bool = false
    @State private var errorMessage: String?
    @State private var stickyIdentifiers: Set<String> = []

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    private var reviewableDecisions: [AssetDecision] {
        let sessionIds = Set(sessionState.swipedIdentifiers)
        return allDecisions.filter { record in
            record.decision == .pendingDelete ||
            stickyIdentifiers.contains(record.localIdentifier) ||
            (record.decision == .kept && sessionIds.contains(record.localIdentifier))
        }
        .sorted { $0.decidedAt > $1.decidedAt }
    }

    private var currentlyVisibleIdentifiers: Set<String> {
        let sessionIds = Set(sessionState.swipedIdentifiers)
        return Set(allDecisions.compactMap { record -> String? in
            if record.decision == .pendingDelete { return record.localIdentifier }
            if record.decision == .kept && sessionIds.contains(record.localIdentifier) {
                return record.localIdentifier
            }
            return nil
        })
    }

    private var pendingDeleteCount: Int {
        reviewableDecisions.count { $0.decision == .pendingDelete }
    }

    var body: some View {
        NavigationStack {
            Group {
                if reviewableDecisions.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                stickyIdentifiers = currentlyVisibleIdentifiers
            }
            .onDisappear {
                stickyIdentifiers = []
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .opacity(pendingDeleteCount > 0 ? 1 : 0)
                    .allowsHitTesting(pendingDeleteCount > 0)
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
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Nothing to review")
                .font(.title.bold())
            Text("Swipe some photos on the Swipe tab. Anything you mark for deletion — or keep this session — will appear here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(reviewableDecisions) { record in
                    ReviewGridItem(record: record) {
                        toggleDecision(for: record)
                    }
                }
            }
            .padding(16)
        }
    }

    private var bottomBar: some View {
        Button(role: .destructive) {
            Task { await confirmDelete() }
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                } else {
                    Image(systemName: "trash.fill")
                    Text("Delete \(pendingDeleteCount) \(pendingDeleteCount == 1 ? "photo" : "photos")")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.red)
        .disabled(isDeleting)
    }

    private func toggleDecision(for record: AssetDecision) {
        let newDecision: DecisionKind = record.decision == .pendingDelete ? .kept : .pendingDelete
        record.decision = newDecision
    }

    private func confirmDelete() async {
        let allIdentifiers = reviewableDecisions
            .filter { $0.decision == .pendingDelete }
            .map(\.localIdentifier)
        guard !allIdentifiers.isEmpty else { return }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: allIdentifiers, options: nil)
        var assetsToDelete: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            assetsToDelete.append(asset)
        }
        let existingIdentifiers = Set(assetsToDelete.map(\.localIdentifier))
        let orphanIdentifiers = allIdentifiers.filter { !existingIdentifiers.contains($0) }

        let store = DecisionStore(context: modelContext)

        // Records whose PHAsset is already gone — sweep them without prompting.
        for identifier in orphanIdentifiers {
            store.record(localIdentifier: identifier, decision: .deleted)
        }
        stickyIdentifiers.subtract(orphanIdentifiers)

        guard !assetsToDelete.isEmpty else { return }

        isDeleting = true
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
            }
            let deletedIdentifiers = assetsToDelete.map(\.localIdentifier)
            for identifier in deletedIdentifiers {
                store.record(localIdentifier: identifier, decision: .deleted)
            }
            stickyIdentifiers.subtract(deletedIdentifiers)
            isDeleting = false
        } catch let phError as PHPhotosError where phError.code == .userCancelled {
            isDeleting = false
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }
}

private struct ReviewGridItem: View {
    let record: AssetDecision
    let onToggle: () -> Void

    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.displayScale) private var displayScale
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true

    @State private var image: UIImage?
    @State private var asset: PHAsset?

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.systemGray6))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.red.opacity(record.decision == .pendingDelete ? 0.25 : 0))
            }
            .overlay(alignment: .topTrailing) {
                decisionBadge
                    .padding(6)
            }
            .animation(.snappy(duration: 0.15), value: record.decision)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture { onToggle() }
            .sensoryFeedback(.selection, trigger: record.decision) { _, _ in hapticsEnabled }
            .task(id: record.localIdentifier) {
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [record.localIdentifier], options: nil)
            var found: PHAsset?
            fetch.enumerateObjects { asset, _, _ in
                found = asset
            }
            asset = found
            if let cached = photoLibrary.cachedImage(for: record.localIdentifier) {
                image = cached
            }
            guard let found else { return }
            let size = CGSize(width: 240 * displayScale, height: 240 * displayScale)
            let loaded = await photoLibrary.requestImage(for: found, targetSize: size)
            if !Task.isCancelled, let loaded { image = loaded }
        }
    }

    private var decisionBadge: some View {
        let isKeep = record.decision != .pendingDelete
        let symbol = isKeep ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: Color = isKeep ? .green : .red
        return Image(systemName: symbol)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .font(.title2)
            .shadow(radius: 2)
    }
}
