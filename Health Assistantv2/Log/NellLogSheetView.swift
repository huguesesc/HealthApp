import SwiftUI

struct NellLogSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: NellLogCategory?
    @State private var naturalText = ""
    @State private var path: [NellLogDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: NellLayout.sectionSpacing) {
                    header
                    categoryGrid

                    if selectedCategory?.supportsNaturalLanguage == true {
                        naturalLanguageCard
                    } else if let selectedCategory {
                        directEntryCard(for: selectedCategory)
                    }
                }
                .padding(NellLayout.screenPadding)
            }
            .background(NellPalette.groupedBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: NellLogDestination.self) { destination in
                switch destination {
                case .meal(let text):
                    MealEntryView(initialText: text)
                case .workout(let text):
                    WorkoutLogView(initialFreeformText: text)
                case .sleep:
                    SleepEntryView()
                case .checkIn:
                    CheckInView()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("What would you like to log?")
                .font(Theme.FontToken.largeScreenTitle)
                .foregroundStyle(NellPalette.textPrimary)

            Text("Choose a category first. Nell will never silently guess where an entry belongs.")
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: Theme.Spacing.sm
        ) {
            ForEach(NellLogCategory.allCases) { category in
                categoryButton(category)
            }
        }
    }

    private func categoryButton(_ category: NellLogCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Image(systemName: category.symbol)
                    .font(.system(size: Theme.Size.prominentIcon, weight: .semibold))
                    .foregroundStyle(category.tint)

                Text(category.title)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text(category.subtitle)
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background(
                selectedCategory == category
                    ? category.tint.opacity(0.12)
                    : NellPalette.surface,
                in: RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                    .stroke(
                        selectedCategory == category ? category.tint : NellPalette.border,
                        lineWidth: selectedCategory == category
                            ? Theme.Border.focused
                            : Theme.Border.standard
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.title), \(category.subtitle)")
        .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
    }

    private var naturalLanguageCard: some View {
        NellCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                NellTextField(
                    title: selectedCategory == .meal ? "Describe your meal" : "Describe your workout",
                    text: $naturalText,
                    prompt: selectedCategory == .meal
                        ? "e.g. Greek yoghurt, berries and oats"
                        : "e.g. Push day — bench 3 × 8 at 60 kg",
                    axis: .vertical,
                    lineLimit: 2...5
                )

                Text("The lightweight structured model fills an editable draft. Nothing is saved until you review it.")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)

                Button {
                    continueWithNaturalText()
                } label: {
                    Label("Review entry", systemImage: "sparkles")
                }
                .buttonStyle(.nellPrimary)
                .disabled(naturalText.trimmed.isEmpty)

                Button("Enter manually") {
                    continueWithNaturalText(allowEmpty: true)
                }
                .buttonStyle(.nellSecondary)
            }
        }
    }

    private func directEntryCard(for category: NellLogCategory) -> some View {
        NellFeaturedCard(tint: category.tint) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Label(category.directMessage, systemImage: category.symbol)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text(category.directDetail)
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)

                Button("Continue") {
                    switch category {
                    case .sleep: path.append(.sleep)
                    case .checkIn: path.append(.checkIn)
                    case .meal, .workout: break
                    }
                }
                .buttonStyle(.nellPrimary)
            }
        }
    }

    private func continueWithNaturalText(allowEmpty: Bool = false) {
        guard let selectedCategory else { return }
        let text = naturalText.trimmed
        guard allowEmpty || !text.isEmpty else { return }

        switch selectedCategory {
        case .meal:
            path.append(.meal(text))
        case .workout:
            path.append(.workout(text))
        case .sleep:
            path.append(.sleep)
        case .checkIn:
            path.append(.checkIn)
        }
    }
}

private enum NellLogDestination: Hashable {
    case meal(String)
    case workout(String)
    case sleep
    case checkIn
}

private enum NellLogCategory: String, CaseIterable, Identifiable {
    case meal
    case workout
    case sleep
    case checkIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meal: return "Meal"
        case .workout: return "Workout"
        case .sleep: return "Sleep"
        case .checkIn: return "Check-in"
        }
    }

    var subtitle: String {
        switch self {
        case .meal: return "Food and nutrition"
        case .workout: return "Training and movement"
        case .sleep: return "Bedtime and recovery"
        case .checkIn: return "Energy, mood and stress"
        }
    }

    var symbol: String {
        switch self {
        case .meal: return "fork.knife"
        case .workout: return "figure.strengthtraining.traditional"
        case .sleep: return "moon.zzz"
        case .checkIn: return "face.smiling"
        }
    }

    var tint: Color {
        switch self {
        case .meal: return NellPalette.nutrition
        case .workout: return NellPalette.training
        case .sleep: return NellPalette.sleep
        case .checkIn: return NellPalette.primary
        }
    }

    var supportsNaturalLanguage: Bool {
        self == .meal || self == .workout
    }

    var directMessage: String {
        switch self {
        case .sleep: return "Log last night's sleep"
        case .checkIn: return "Record how you feel today"
        case .meal, .workout: return title
        }
    }

    var directDetail: String {
        switch self {
        case .sleep:
            return "Add bedtime, wake time, perceived quality and optional nap information."
        case .checkIn:
            return "Record energy, mood, soreness, focus and stress without making a medical claim."
        case .meal, .workout:
            return ""
        }
    }
}

#Preview {
    NellLogSheetView()
        .modelContainer(PersistenceController.preview.container)
}
