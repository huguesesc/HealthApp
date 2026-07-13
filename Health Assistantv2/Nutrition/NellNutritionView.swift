import SwiftData
import SwiftUI

struct NellNutritionView: View {
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]
    @State private var showingMealEntry = false

    var body: some View {
        NellScreen {
            header
            summary
            mealTimeline
            recentHistory
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingMealEntry = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log a meal")
            }
        }
        .sheet(isPresented: $showingMealEntry) {
            NavigationStack { MealEntryView() }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Nutrition")
                    .font(Theme.FontToken.largeScreenTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text("Food and macro tracking based only on what you log.")
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            Spacer()

            Button {
                showingMealEntry = true
            } label: {
                Label("Log Meal", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(width: NellLayout.minimumTouchTarget, height: NellLayout.minimumTouchTarget)
                    .background(NellPalette.primary, in: Circle())
                    .foregroundStyle(Color.white)
            }
            .accessibilityLabel("Log a meal")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(
                title: "Today's Summary",
                subtitle: mealsToday.isEmpty
                    ? "No meals logged today."
                    : "Totals from \(mealsToday.count) logged meal(s)."
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                NellMetricTile(
                    title: "Calories",
                    value: calorieValue,
                    detail: "Logged total",
                    systemImage: "flame",
                    tint: NellPalette.amber
                )
                NellMetricTile(
                    title: "Protein",
                    value: macroValue(proteinToday),
                    detail: "Logged total",
                    systemImage: "circle.hexagongrid",
                    tint: NellPalette.nutrition
                )
                NellMetricTile(
                    title: "Carbs",
                    value: macroValue(carbsToday),
                    detail: "Logged total",
                    systemImage: "leaf",
                    tint: NellPalette.primary
                )
                NellMetricTile(
                    title: "Fat",
                    value: macroValue(fatToday),
                    detail: "Logged total",
                    systemImage: "drop",
                    tint: NellPalette.warning
                )
            }

            Text("Nell does not invent a nutrition target. Goals will appear here only after you set them explicitly.")
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textTertiary)
        }
    }

    @ViewBuilder
    private var mealTimeline: some View {
        NellSectionHeader(title: "Today's Meals")

        if mealsToday.isEmpty {
            NellEmptyState(
                title: "No meals logged",
                message: "Add a meal manually or ask the lightweight estimator to prepare an editable draft.",
                systemImage: "fork.knife",
                actionTitle: "Log a meal"
            ) {
                showingMealEntry = true
            }
        } else {
            NellCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(mealsToday.enumerated()), id: \.offset) { index, meal in
                        mealRow(meal)
                        if index < mealsToday.count - 1 {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentHistory: some View {
        let earlier = meals.filter { !Calendar.current.isDateInToday($0.timestamp) }
        if !earlier.isEmpty {
            NellSectionHeader(title: "Recent History")
            NellCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(earlier.prefix(8).enumerated()), id: \.offset) { index, meal in
                        mealRow(meal)
                        if index < min(earlier.count, 8) - 1 {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
            }
        }
    }

    private func mealRow(_ meal: Meal) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Circle()
                .fill(mealDotColour(meal))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(meal.rawText)
                    .font(Theme.FontToken.body)
                    .foregroundStyle(NellPalette.textPrimary)
                    .lineLimit(2)

                Text(meal.timestamp, format: .dateTime.weekday(.abbreviated).hour().minute())
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
        .accessibilityElement(children: .combine)
    }

    private var mealsToday: [Meal] {
        meals.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var calorieValue: String {
        let values = mealsToday.compactMap(\.calories)
        guard !values.isEmpty else { return "—" }
        return "\(values.reduce(0, +))"
    }

    private var proteinToday: Double? { sum(mealsToday.compactMap(\.proteinGrams)) }
    private var carbsToday: Double? { sum(mealsToday.compactMap(\.carbsGrams)) }
    private var fatToday: Double? { sum(mealsToday.compactMap(\.fatGrams)) }

    private func sum(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +)
    }

    private func macroValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded())) g"
    }

    private func mealDotColour(_ meal: Meal) -> Color {
        let hour = Calendar.current.component(.hour, from: meal.timestamp)
        switch hour {
        case 5..<11: return NellPalette.nutrition
        case 11..<16: return NellPalette.amber
        case 16..<22: return NellPalette.primary
        default: return NellPalette.sleep
        }
    }
}

#Preview {
    NavigationStack { NellNutritionView() }
        .modelContainer(PersistenceController.preview.container)
}
