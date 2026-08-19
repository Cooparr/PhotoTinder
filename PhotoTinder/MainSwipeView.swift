import SwiftUI

struct MainSwipeView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("Access granted")
                .font(.title2.bold())

            Text(photoLibrary.authState == .limited
                 ? "Limited access — swipe UI coming next."
                 : "Full access — swipe UI coming next.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    MainSwipeView()
        .environment(PhotoLibraryService())
}
