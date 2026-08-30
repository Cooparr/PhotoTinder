import StoreKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("deletedPhotoCount") private var deletedPhotoCount: Int = 0
    @AppStorage("deletedVideoCount") private var deletedVideoCount: Int = 0
    @AppStorage("deletedBytes") private var deletedBytes: Double = 0
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    private let shareMessage = "I'm using PhotoTinder to clean up my photo library — swipe left to trash, right to keep. Check it out."

    private var hasCleanupStats: Bool {
        deletedPhotoCount > 0 || deletedVideoCount > 0 || deletedBytes > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                if hasCleanupStats {
                    Section("Stats") {
                        cleanupRow(
                            icon: "photo.fill",
                            label: "Photos deleted",
                            value: deletedPhotoCount.formatted()
                        )
                        cleanupRow(
                            icon: "video.fill",
                            label: "Videos deleted",
                            value: deletedVideoCount.formatted()
                        )
                        cleanupRow(
                            icon: "internaldrive.fill",
                            label: "Storage freed",
                            value: formattedBytes
                        )
                    }
                }

                Section("Settings") {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label("App Settings", systemImage: "apps.iphone")
                    }

                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                }

                Section("Social") {
                    ShareLink(item: shareMessage) {
                        Label("Share with friends", systemImage: "square.and.arrow.up.fill")
                    }

                    Button {
                        requestReview()
                    } label: {
                        Label("Rate PhotoTinder", systemImage: "star.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func cleanupRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(deletedBytes), countStyle: .file)
    }
}

#Preview {
    SettingsView()
}
