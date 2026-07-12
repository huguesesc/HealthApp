import SwiftUI
import UIKit

enum NellLogCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case meal = "Meal"
    case workout = "Workout"
    case sleep = "Sleep"
    case checkIn = "Check-in"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .meal: return "fork.knife"
        case .workout: return "dumbbell.fill"
        case .sleep: return "moon.zzz.fill"
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

    var prompt: String {
        switch self {
        case .meal: return "Describe what you ate and any useful portion details."
        case .workout: return "Describe the workout, exercises, sets or duration."
        case .sleep: return "Describe when you slept and how it felt."
        case .checkIn: return "Describe your mood, energy or anything worth noting."
        }
    }

    var actionTitle: String {
        "Continue to \(rawValue.lowercased()) logger"
    }
}

/// Explicitly separates category choice from natural-language entry. The typed
/// description remains visible through the handoff instead of being discarded or
/// silently interpreted as a meal.
struct NellLogSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var category: NellLogCategory?
    @State private var descriptionText = ""
    @State private var route: NellLogRoute?

    var body: some View {
        NavigationStack {
            NellScreen {
                header
                categoryPicker
                descriptionField
                continueButton
            }
            .navigationDestination(item: $route) { route in
                NellLogHandoffView(route: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            NellBrandLockup(compact: true, showsDescriptor: false)
            Text("What would you like to log?")
                .font(Theme.FontToken.largeScreenTitle)
                .foregroundStyle(NellPalette.textPrimary)
            Text("Choose a category first. Nell will not silently reinterpret the entry as something else.")
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Category")
                .font(Theme.FontToken.sectionTitle)
                .foregroundStyle(NellPalette.textPrimary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.sm
            ) {
                ForEach(NellLogCategory.allCases) { option in
                    Button {
                        category = option
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: option.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(option.rawValue)
                                .font(Theme.FontToken.body.weight(.semibold))
                            Spacer(minLength: 0)
                            if category == option {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundStyle(category == option ? option.tint : NellPalette.textPrimary)
                        .padding(Theme.Spacing.md)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .background(
                            option.tint.opacity(category == option ? 0.13 : 0.04),
                            in: RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                                .stroke(
                                    category == option ? option.tint : NellPalette.border,
                                    lineWidth: category == option ? 1.5 : Theme.Border.standard
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(category == option ? .isSelected : [])
                }
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Description")
                .font(Theme.FontToken.sectionTitle)
                .foregroundStyle(NellPalette.textPrimary)

            TextField(
                category?.prompt ?? "Select a category, then describe the entry.",
                text: $descriptionText,
                axis: .vertical
            )
            .lineLimit(4...8)
            .padding(Theme.Spacing.md)
            .frame(minHeight: 132, alignment: .topLeading)
            .background(
                NellPalette.surface,
                in: RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                    .stroke(NellPalette.border, lineWidth: Theme.Border.standard)
            }
            .disabled(category == nil)
        }
    }

    private var continueButton: some View {
        Button {
            guard let category else { return }
            route = NellLogRoute(
                category: category,
                descriptionText: trimmedDescription
            )
        } label: {
            Label(
                category?.actionTitle ?? "Choose a category",
                systemImage: "arrow.right"
            )
        }
        .buttonStyle(.nellPrimary)
        .disabled(category == nil || trimmedDescription.isEmpty)
    }

    private var trimmedDescription: String {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct NellLogRoute: Hashable, Identifiable, Sendable {
    let category: NellLogCategory
    let descriptionText: String

    var id: String {
        "\(category.rawValue):\(descriptionText)"
    }
}

private struct NellLogHandoffView: View {
    let route: NellLogRoute

    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    NellSectionHeader(
                        title: route.category.rawValue,
                        subtitle: "Your original description stays available below."
                    )

                    NellCard {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Label("Original description", systemImage: "text.quote")
                                .font(Theme.FontToken.cardTitle)
                                .foregroundStyle(route.category.tint)

                            Text(route.descriptionText)
                                .font(Theme.FontToken.body)
                                .foregroundStyle(NellPalette.textPrimary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                UIPasteboard.general.string = route.descriptionText
                                copied = true
                            } label: {
                                Label(copied ? "Copied" : "Copy description", systemImage: copied ? "checkmark" : "doc.on.doc")
                            }
                            .font(Theme.FontToken.secondaryBody.weight(.semibold))
                            .foregroundStyle(route.category.tint)
                        }
                    }
                }
                .padding(.horizontal, NellLayout.screenPadding)
                .padding(.top, Theme.Spacing.sm)
            }
            .frame(maxHeight: 260)
            .background(NellPalette.groupedBackground)

            Divider()

            destination
        }
        .navigationTitle(route.category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var destination: some View {
        switch route.category {
        case .meal:
            MealEntryView()
        case .workout:
            WorkoutLogView()
        case .sleep:
            SleepEntryView()
        case .checkIn:
            CheckInView()
        }
    }
}

#Preview {
    NellLogSheetView()
        .modelContainer(PersistenceController.preview.container)
}
