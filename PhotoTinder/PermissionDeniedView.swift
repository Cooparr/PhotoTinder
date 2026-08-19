import SwiftUI

struct PermissionDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("Photo access is off")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("PhotoTinder needs access to your photo library to work. Turn it on in Settings and come back.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                if let url = URL(string: "app-settings:") {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
    }
}

#Preview {
    PermissionDeniedView()
}
