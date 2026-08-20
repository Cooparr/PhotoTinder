import Foundation
import SwiftData

struct DecisionStore {
    let context: ModelContext

    func decidedIdentifiers() -> Set<String> {
        let descriptor = FetchDescriptor<AssetDecision>()
        guard let all = try? context.fetch(descriptor) else { return [] }
        return Set(all.map(\.localIdentifier))
    }

    func decision(for identifier: String) -> DecisionKind? {
        let descriptor = FetchDescriptor<AssetDecision>(
            predicate: #Predicate { $0.localIdentifier == identifier }
        )
        return (try? context.fetch(descriptor).first)?.decision
    }

    func record(localIdentifier: String, decision: DecisionKind) {
        let descriptor = FetchDescriptor<AssetDecision>(
            predicate: #Predicate { $0.localIdentifier == localIdentifier }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.decision = decision
            existing.decidedAt = .now
        } else {
            context.insert(
                AssetDecision(localIdentifier: localIdentifier, decision: decision)
            )
        }
        try? context.save()
    }

    func pendingDeletes() -> [AssetDecision] {
        let descriptor = FetchDescriptor<AssetDecision>()
        guard let all = try? context.fetch(descriptor) else { return [] }
        return all.filter { $0.decision == .pendingDelete }
    }

    func remove(localIdentifier: String) {
        let descriptor = FetchDescriptor<AssetDecision>(
            predicate: #Predicate { $0.localIdentifier == localIdentifier }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }
}
