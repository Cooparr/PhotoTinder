import Foundation
import SwiftUI

@Observable
final class SessionState {
    var swipedIdentifiers: [String] = []

    func append(_ identifier: String) {
        swipedIdentifiers.append(identifier)
    }

    func popLast() -> String? {
        swipedIdentifiers.popLast()
    }

    var isEmpty: Bool { swipedIdentifiers.isEmpty }
}
