import SwiftData
import SwiftUI

/// Natural-language meal logging. Macros can be typed by hand or estimated with
/// AI (`AIClient.parseMeal`) from the description — the estimate fills the fields
/// so the user can correct them before saving.
struct MealEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]

    @State private var text = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    @State private var isEstimating = false
    @State private var estimateNote: String?
    @State private var estimateError: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }
    private var hasKey: Bool { APIKeyStore.read()?.isEmpty == false }

    var body: some View {
        Form {
            Section {
                TextField("Describe it, e.g. two eggs and toast", text: $text, axis: .vertical)

                Button {
                    estimateWithAI()
                } label: {
                    if isEstimating {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Estimating…")
                        }
                    } else {
                        Label("Estimate with AI", systemImage: "sparkles")
                    }
                }
                .disabled(text.trimmed.isEmpty || isEstimating)

                if let estimateNote {
                    Text(estimateNote)
                        .font(.caption)
                        .foregroundStyle(Theme.honey)
                }
                if let estimateError {
                    Text(estimateError)
                        .font(.caption)
                        .foregroundStyle(Theme.clay)
                }

                TextField("Calories (optional)", text: $calories)
                    .keyboardType(.numberPad)
                TextField("Protein g (optional)", text: $protein)
                    .keyboardType(.decimalPad)
                TextField("Carbs g (optional)", text: $carbs)
                    .keyboardType(.decimalPad)
                TextField("Fat g (optional)", text: $fat)
                    .keyboardType(.decimalPad)

                Button("Add meal", action: addMeal)
                    .disabled(text.trimmed.isEmpty)
            } header: {
                Text("Log a meal")
            } footer: {
                Text("Estimates are rough — portions are guessed from your description. "
                    + "Adjust the numbers before saving if they look off.")
            }

            Section("History") {
                if meals.isEmpty {
                    Text("No meals logged yet.").foregroundStyle(.secondary)
                }
                ForEach(meals) { meal in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.rawText)
                        HStack {
                            if let calories = meal.calories {
                                Text("~\(calories) kcal")
                            }
                            Text(meal.timestamp, style: .date)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Meals")
    }

    private func estimateWithAI() {
        estimateError = nil
        estimateNote = nil
        guard hasKey else {
            estimateError = "Add your Claude API key in Settings first."
            return
        }
        isEstimating = true
        Task { @MainActor in
            do {
                let estimate = try await AIClientFactory.makeDefault().parseMeal(text: text.trimmed)
                calories = String(estimate.calories)
                protein = String(format: "%g", estimate.proteinGrams)
                carbs = String(format: "%g", estimate.carbsGrams)
                fat = String(format: "%g", estimate.fatGrams)
                estimateNote = estimate.uncertaintyNote
            } catch {
                estimateError = "Couldn't estimate that. Check your connection and try again."
            }
            isEstimating = false
        }
    }

    private func addMeal() {
        let meal = Meal(rawText: text.trimmed)
        meal.calories = Int(calories)
        meal.proteinGrams = Double(protein)
        meal.carbsGrams = Double(carbs)
        meal.fatGrams = Double(fat)
        meal.uncertaintyNote = estimateNote
        repo.addMeal(meal)
        text = ""; calories = ""; protein = ""; carbs = ""; fat = ""
        estimateNote = nil; estimateError = nil
    }
}

#Preview {
    NavigationStack { MealEntryView() }
        .modelContainer(PersistenceController.preview.container)
}
