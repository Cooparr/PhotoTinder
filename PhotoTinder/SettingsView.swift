import StoreKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("appTheme") private var theme: AppTheme = .blue
    @AppStorage("deletedPhotoCount") private var deletedPhotoCount: Int = 0
    @AppStorage("deletedVideoCount") private var deletedVideoCount: Int = 0
    @AppStorage("deletedBytes") private var deletedBytes: Double = 0
    @State private var showingThemeSheet: Bool = false
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    private let shareMessage = String(localized: "I'm using PhotoTinder to clean up my photo library — swipe left to trash, right to keep. Check it out.")

    private var hasCleanupStats: Bool {
        deletedPhotoCount > 0 || deletedVideoCount > 0 || deletedBytes > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                if hasCleanupStats {
                    Section("Statistics") {
                        storageHero
                        cleanupRow(
                            icon: "photo.fill",
                            label: "Photos cleared",
                            value: deletedPhotoCount.formatted()
                        )
                        cleanupRow(
                            icon: "video.fill",
                            label: "Videos cleared",
                            value: deletedVideoCount.formatted()
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

                    themeRow

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
            .sheet(isPresented: $showingThemeSheet) {
                ThemeSheetView(theme: $theme)
            }
        }
    }

    private var themeRow: some View {
        Button {
            showingThemeSheet = true
        } label: {
            HStack {
                Label("Theme", systemImage: "paintbrush.fill")
                    .foregroundStyle(.primary)
                Spacer()
                Circle()
                    .fill(theme.color)
                    .frame(width: 20, height: 20)
            }
        }
    }

    private var storageHero: some View {
        VStack(spacing: 4) {
            Text(formattedBytes)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("Storage freed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
