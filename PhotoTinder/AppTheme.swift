import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case blue
    case teal
    case green
    case yellow
    case orange
    case red
    case pink
    case purple
    case indigo
    case mint

    var id: Self { self }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .teal: return .teal
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .purple: return .purple
        case .indigo: return .indigo
        case .mint: return .mint
        }
    }
}
