import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var detail = ""
    @State private var frequency: HabitFrequency = .daily

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                VStack(spacing: 18) {
                    OrbitCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "New Habit", subtitle: "Add the next action to your orbit.", systemImage: "plus.circle")

                            TextField("Habit name", text: $name)
                                .textFieldStyle(OrbitTextFieldStyle())

                            TextField("Notes (optional)", text: $detail)
                                .textFieldStyle(OrbitTextFieldStyle())

                            Picker("Frequency", selection: $frequency) {
                                ForEach(HabitFrequency.allCases) { frequency in
                                    Text(frequency.rawValue).tag(frequency)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    Button("Save Habit") {
                        saveHabit()
                    }
                    .buttonStyle(PrimaryOrbitButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Add Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(OrbitTheme.accent)
                }
            }
        }
    }

    private func saveHabit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        modelContext.insert(Habit(name: trimmedName, detail: detail, frequency: frequency))
        try? modelContext.save()
        dismiss()
    }
}
