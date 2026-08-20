import Photos
import SwiftData
import SwiftUI
import UIKit

struct SessionReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let sessionIdentifiers: [String]
    let onFinished: () -> Void

    @State private var entries: [Entry] = []
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    struct Entry: Identifiable {
        let asset: PHAsset
        var decision: DecisionKind
        var id: String { asset.localIdentifier }
    }

    private var pendingDeleteCount: Int {
        entries.count { $0.decision == .pendingDelete }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach($entries) { $entry in
                        ReviewThumbnail(entry: entry) {
                            toggleDecision(&entry)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Session review")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onFinished()
                        dismiss()
                    }
                    .disabled(isDeleting)
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
        .task { loadEntries() }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if pendingDeleteCount > 0 {
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
    }

    private func loadEntries() {
        let store = DecisionStore(context: modelContext)
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: sessionIdentifiers, options: nil)
        var byId: [String: PHAsset] = [:]
        fetch.enumerateObjects { asset, _, _ in
            byId[asset.localIdentifier] = asset
        }

        var loaded: [Entry] = []
        for id in sessionIdentifiers.reversed() {
            guard let asset = byId[id] else { continue }
            let decision = store.decision(for: id) ?? .kept
            loaded.append(Entry(asset: asset, decision: decision))
        }
        entries = loaded
    }

    private func toggleDecision(_ entry: inout Entry) {
        let newDecision: DecisionKind = entry.decision == .pendingDelete ? .kept : .pendingDelete
        entry.decision = newDecision
        DecisionStore(context: modelContext).record(localIdentifier: entry.id, decision: newDecision)
    }

    private func confirmDelete() async {
        let assetsToDelete = entries.compactMap { $0.decision == .pendingDelete ? $0.asset : nil }
        guard !assetsToDelete.isEmpty else { return }

        isDeleting = true
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
            }
            let store = DecisionStore(context: modelContext)
            for asset in assetsToDelete {
                store.record(localIdentifier: asset.localIdentifier, decision: .deleted)
            }
            onFinished()
            dismiss()
        } catch let phError as PHPhotosError where phError.code == .userCancelled {
            isDeleting = false
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }
}

private struct ReviewThumbnail: View {
    let entry: SessionReviewView.Entry
    let onToggle: () -> Void

    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.displayScale) private var displayScale

    @State private var image: UIImage?

    var body: some View {
        Button(action: onToggle) {
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
                    if entry.decision == .pendingDelete {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.red.opacity(0.25))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    decisionBadge
                        .padding(6)
                }
        }
        .buttonStyle(.plain)
        .onChange(of: entry.asset.localIdentifier, initial: true) {
            image = photoLibrary.cachedImage(for: entry.asset.localIdentifier)
        }
        .task(id: entry.asset.localIdentifier) {
            let size = CGSize(width: 240 * displayScale, height: 240 * displayScale)
            let loaded = await photoLibrary.requestImage(for: entry.asset, targetSize: size)
            if !Task.isCancelled, let loaded { image = loaded }
        }
    }

    private var decisionBadge: some View {
        let isKeep = entry.decision != .pendingDelete
        let symbol = isKeep ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: Color = isKeep ? .green : .red
        return Image(systemName: symbol)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .font(.title2)
            .shadow(radius: 2)
    }
}
