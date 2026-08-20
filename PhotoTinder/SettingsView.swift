import StoreKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    private let shareMessage = "I'm using PhotoTinder to clean up my photo library — swipe left to trash, right to keep. Check it out."

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                }

                Section {
                    ShareLink(item: shareMessage) {
                        Label("Share with friends", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        requestReview()
                    } label: {
                        Label("Rate PhotoTinder", systemImage: "star")
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
