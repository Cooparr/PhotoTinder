import SwiftUI

struct PermissionPromptView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("Clean up your photo library")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Swipe left to delete, right to keep. PhotoTinder remembers every decision, so you never review the same photo twice.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await photoLibrary.requestAccess() }
                } label: {
                    Text("Grant Photo Access")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                VStack(spacing: 8) {
                    Text("Your photos stay on your device.\nWe don't store, back up, or copy them anywhere.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(32)
    }
}

#Preview {
    PermissionPromptView()
        .environment(PhotoLibraryService())
}
