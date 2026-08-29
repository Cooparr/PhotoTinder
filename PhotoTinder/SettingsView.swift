import StoreKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    private let shareMessage = "I'm using PhotoTinder to clean up my photo library — swipe left to trash, right to keep. Check it out."

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label("App Settings", systemImage: "apps.iphone")
                    }

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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
