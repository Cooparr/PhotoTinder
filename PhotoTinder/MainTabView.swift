import SwiftData
import SwiftUI

struct MainTabView: View {
    @Query private var allDecisions: [AssetDecision]

    private var pendingDeleteCount: Int {
        allDecisions.count { $0.decision == .pendingDelete }
    }

    var body: some View {
        TabView {
            MainSwipeView()
                .tabItem { Label("Swipe", systemImage: "photo.on.rectangle.angled.fill") }

            ReviewTabView()
                .tabItem { Label("Review", systemImage: "list.bullet.rectangle.portrait") }
                .badge(pendingDeleteCount)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
