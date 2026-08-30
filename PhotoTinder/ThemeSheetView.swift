import SwiftUI

struct ThemeSheetView: View {
    @Binding var theme: AppTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(AppTheme.allCases) { option in
                        Button {
                            theme = option
                        } label: {
                            HStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 24, height: 24)
                                Text(option.rawValue.capitalized)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if theme == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .font(.body.weight(.semibold))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
