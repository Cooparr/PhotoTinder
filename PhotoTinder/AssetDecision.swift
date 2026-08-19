import Foundation
import SwiftData

enum DecisionKind: String, Codable, CaseIterable, Sendable {
    case kept
    case pendingDelete
    case deleted
}

@Model
final class AssetDecision {
    @Attribute(.unique) var localIdentifier: String
    var decision: DecisionKind
    var decidedAt: Date

    init(localIdentifier: String, decision: DecisionKind, decidedAt: Date = .now) {
        self.localIdentifier = localIdentifier
        self.decision = decision
        self.decidedAt = decidedAt
    }
}
