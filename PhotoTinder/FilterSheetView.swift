import SwiftUI

struct FilterSheetView: View {
    @Binding var filter: MediaFilter
    @Binding var sort: SwipeSort
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Show") {
                    ForEach(MediaFilter.allCases) { option in
                        row(
                            label: option.label,
                            symbol: option.symbol,
                            isSelected: filter == option
                        ) {
                            filter = option
                        }
                    }
                }

                Section("Sort") {
                    ForEach(SwipeSort.allCases) { option in
                        row(
                            label: option.label,
                            symbol: option.symbol,
                            isSelected: sort == option
                        ) {
                            sort = option
                        }
                    }
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(
        label: String,
        symbol: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if let symbol {
                    Label(label, systemImage: symbol)
                        .foregroundStyle(.primary)
                } else {
                    Text(label)
                        .foregroundStyle(.primary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .font(.body.weight(.semibold))
                }
            }
        }
    }
}
