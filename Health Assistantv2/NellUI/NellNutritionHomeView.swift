import SwiftData
import SwiftUI

struct NellNutritionHomeView: View {
    @Query(sort: \DailyRollup.date, order: .reverse)
    private var rollups: [DailyRollup]

    private var today: DailyRollup? {
        rollups.first(where: { Calendar.current.isDateInToday($0.date) })
    }

    var body: some View {
        NellScreen {
            header
            summaryCard
            logMealAction
            recentDaysSection
            guidanceCard
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .accessibilityLabel("Profile and settings")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text("Nutrition")
                .font(Theme.FontToken.largeScreenTitle)
                .foregroundStyle(NellPalette.textPrimary)
            Text("Food and meal tracking")
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }

    private var summaryCard: some View {
        NellFeaturedCard(tint: NellPalette.nutrition) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Today's summary")
                        .font(Theme.FontToken.sectionTitle)
                        .foregroundStyle(NellPalette.textPrimary)

                    HStack(spacing: Theme.Spacing.lg) {
                        summaryValue(
                            title: "Meals",
                            value: "\(today?.mealsLogged ?? 0)"
                        )
                        summaryValue(
                            title: "Calories",
                            value: calorieText
                        )
                    }

                    Text("Macro totals appear when protein, carbohydrates and fat are recorded in individual meals.")
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Theme.Spacing.sm)

                NellMascotView(pose: .nutrition)
                    .frame(width: 96, height: 96)
            }
        }
    }

    private func summaryValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.FontToken.metric)
                .foregroundStyle(NellPalette.textPrimary)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }

    private var logMealAction: some View {
        NavigationLink {
            MealEntryView()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30, weight: .semibold))

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Log a meal")
                        .font(Theme.FontToken.cardTitle)
                    Text("Describe it naturally, then review the estimate before saving.")
                        .font(Theme.FontToken.secondaryBody)
                        .opacity(0.86)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Theme.Spacing.xs)
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(Color.white)
            .padding(Theme.Spacing.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                NellPalette.primary,
                in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var recentDaysSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(
                title: "Recent meal logging",
                subtitle: "Daily totals from your saved records"
            )

            if recentNutritionDays.isEmpty {
                NellEmptyState(
                    title: "No meals logged yet",
                    message: "Your recent daily meal totals will appear here.",
                    systemImage: "fork.knife"
                )
            } else {
                NellCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(recentNutritionDays.enumerated()), id: \.element.date) { index, day in
                            HStack(spacing: Theme.Spacing.sm) {
                                Circle()
                                    .fill(NellPalette.nutrition)
                                    .frame(width: 9, height: 9)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text(day.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(Theme.FontToken.body.weight(.semibold))
                                        .foregroundStyle(NellPalette.textPrimary)
                                    Text("\(day.mealsLogged) meal\(day.mealsLogged == 1 ? "" : "s")")
                                        .font(Theme.FontToken.caption)
                                        .foregroundStyle(NellPalette.textSecondary)
                                }

                                Spacer()

                                Text("\(day.totalCalories.formatted()) kcal")
                                    .font(Theme.FontToken.secondaryBody)
                                    .foregroundStyle(NellPalette.textSecondary)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)

                            if index < recentNutritionDays.count - 1 {
                                Divider().padding(.leading, Theme.Spacing.xl)
                            }
                        }
                    }
                }
            }
        }
    }

    private var guidanceCard: some View {
        NellCoachSuggestionCard(
            title: "Estimates remain editable",
            message: "AI nutrition values are rough estimates. Review portions and totals before saving them."
        )
    }

    private var calorieText: String {
        let calories = today?.totalCalories ?? 0
        return calories > 0 ? calories.formatted() : "—"
    }

    private var recentNutritionDays: [DailyRollup] {
        Array(rollups.filter { $0.mealsLogged > 0 }.prefix(7))
    }
}

#Preview {
    NavigationStack {
        NellNutritionHomeView()
    }
    .modelContainer(PersistenceController.preview.container)
}
