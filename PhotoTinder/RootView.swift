import SwiftUI

struct RootView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch photoLibrary.authState {
            case .unknown:
                PermissionPromptView()
            case .authorized, .limited:
                MainTabView()
            case .denied:
                PermissionDeniedView()
            }
        }
        .animation(.default, value: photoLibrary.authState)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                photoLibrary.refreshAuthState()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(PhotoLibraryService())
}
