import SwiftData
import SwiftUI

/// Natural-language meal logging with optional manual macros. AI estimation
/// (`AIClient.parseMeal`) gets wired in at M2; for now macros are entered by hand.
struct MealEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]

    @State private var text = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Form {
            Section("Log a meal") {
                TextField("Describe it, e.g. two eggs and toast", text: $text, axis: .vertical)
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

    private func addMeal() {
        let meal = Meal(rawText: text.trimmed)
        meal.calories = Int(calories)
        meal.proteinGrams = Double(protein)
        meal.carbsGrams = Double(carbs)
        meal.fatGrams = Double(fat)
        repo.addMeal(meal)
        text = ""; calories = ""; protein = ""; carbs = ""; fat = ""
    }
}

#Preview {
    NavigationStack { MealEntryView() }
        .modelContainer(PersistenceController.preview.container)
}
