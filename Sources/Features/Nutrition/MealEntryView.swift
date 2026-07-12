import SwiftData
import SwiftUI

/// Editable meal draft. Natural-language estimation uses the lightweight one-shot
/// model and never saves until the user reviews the result.
struct MealEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]

    @State private var text: String
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    @State private var isEstimating = false
    @State private var estimateNote: String?
    @State private var estimateError: String?
    @State private var savedMessage: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }
    private var hasKey: Bool { APIKeyStore.read()?.isEmpty == false }

    init(initialText: String = "") {
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NellScreen {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Log a Meal")
                    .font(Theme.FontToken.largeScreenTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text("Describe it naturally, then review every estimate before saving.")
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            NellCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    NellTextField(
                        title: "What did you have?",
                        text: $text,
                        prompt: "e.g. two eggs, toast and coffee",
                        axis: .vertical,
                        lineLimit: 2...6
                    )

                    Button {
                        estimateWithAI()
                    } label: {
                        if isEstimating {
                            HStack(spacing: Theme.Spacing.xs) {
                                ProgressView()
                                    .tint(Color.white)
                                Text("Estimating…")
                            }
                        } else {
                            Label("Estimate with AI", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.nellPrimary)
                    .disabled(text.trimmed.isEmpty || isEstimating)

                    if !hasKey {
                        Label("Coach connection is required only for estimation. Manual logging still works.", systemImage: "key")
                            .font(Theme.FontToken.caption)
                            .foregroundStyle(NellPalette.textSecondary)
                    }

                    if let estimateNote {
                        Label(estimateNote, systemImage: "info.circle")
                            .font(Theme.FontToken.caption)
                            .foregroundStyle(NellPalette.warning)
                    }

                    if let estimateError {
                        Label(estimateError, systemImage: "exclamationmark.triangle")
                            .font(Theme.FontToken.caption)
                            .foregroundStyle(NellPalette.destructive)
                    }
                }
            }

            NellSectionHeader(
                title: "Editable estimate",
                subtitle: "Leave any value blank when it is unknown."
            )

            NellCard {
                VStack(spacing: Theme.Spacing.sm) {
                    numberField("Calories", unit: "kcal", text: $calories, keyboard: .numberPad)
                    Divider()
                    numberField("Protein", unit: "g", text: $protein, keyboard: .decimalPad)
                    Divider()
                    numberField("Carbohydrates", unit: "g", text: $carbs, keyboard: .decimalPad)
                    Divider()
                    numberField("Fat", unit: "g", text: $fat, keyboard: .decimalPad)
                }
            }

            Button("Save meal", action: addMeal)
                .buttonStyle(.nellPrimary)
                .disabled(text.trimmed.isEmpty)

            if let savedMessage {
                NellConfirmationCard(title: "Meal logged", message: savedMessage)
            }

            if !meals.isEmpty {
                NellSectionHeader(title: "Recent meals")
                NellCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(meals.prefix(5).enumerated()), id: \.element.persistentModelID) { index, meal in
                            mealRow(meal)
                            if index < min(meals.count, 5) - 1 {
                                Divider().padding(.leading, Theme.Spacing.md)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Meal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func numberField(
        _ title: String,
        unit: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.FontToken.body)
                .foregroundStyle(NellPalette.textPrimary)

            Spacer()

            TextField("Optional", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)

            Text(unit)
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textTertiary)
                .frame(width: 34, alignment: .leading)
        }
        .frame(minHeight: NellLayout.minimumTouchTarget)
    }

    private func mealRow(_ meal: Meal) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Circle()
                .fill(NellPalette.nutrition)
                .frame(width: 9, height: 9)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(meal.rawText)
                    .font(Theme.FontToken.body)
                    .foregroundStyle(NellPalette.textPrimary)
                    .lineLimit(2)

                Text(meal.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textTertiary)
            }

            Spacer(minLength: Theme.Spacing.xs)

            if let calories = meal.calories {
                Text("\(calories) kcal")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
    }

    private func estimateWithAI() {
        estimateError = nil
        estimateNote = nil
        savedMessage = nil

        guard hasKey else {
            estimateError = "No Claude API key is saved. Review Coach connection in Settings."
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
                estimateError = AIErrorMessage.describe(error, operation: "meal estimate")
            }
            isEstimating = false
        }
    }

    private func addMeal() {
        let description = text.trimmed
        guard !description.isEmpty else { return }

        let meal = Meal(rawText: description)
        meal.calories = Int(calories)
        meal.proteinGrams = Double(protein)
        meal.carbsGrams = Double(carbs)
        meal.fatGrams = Double(fat)
        meal.uncertaintyNote = estimateNote
        repo.addMeal(meal)

        savedMessage = "\(description) was saved on this device."
        text = ""
        calories = ""
        protein = ""
        carbs = ""
        fat = ""
        estimateNote = nil
        estimateError = nil
    }
}

#Preview {
    NavigationStack { MealEntryView(initialText: "Greek yoghurt, berries and oats") }
        .modelContainer(PersistenceController.preview.container)
}
