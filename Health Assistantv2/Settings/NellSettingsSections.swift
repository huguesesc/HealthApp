import SwiftData
import SwiftUI

enum NellAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Lightweight personalisation plus links into the authoritative SwiftData
/// profile. Goals, training context and movement considerations are no longer
/// edited through a second AppStorage-backed profile path.
struct NellProfilePreferencesView: View {
    @AppStorage("nell.profile.displayName") private var displayName = ""
    @Query(sort: \HealthProfile.createdAt, order: .forward) private var profiles: [HealthProfile]

    var body: some View {
        Form {
            Section {
                TextField("Preferred name", text: $displayName)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Personalisation")
            } footer: {
                Text("The preferred name is a display preference. Coach-relevant health and training information is stored in the local SwiftData profile.")
            }

            Section {
                NavigationLink {
                    ProfileView()
                } label: {
                    Label("Edit coaching profile", systemImage: "list.clipboard")
                }

                NavigationLink {
                    HealthConsiderationsView()
                } label: {
                    Label("Movement considerations", systemImage: "figure.mind.and.body")
                }

                if let profile = profiles.first {
                    LabeledContent("Primary goal", value: profile.primaryGoal.displayName)
                    LabeledContent("Experience", value: profile.experienceLevel.displayName)

                    if let detail = profile.goalDetail, !detail.trimmed.isEmpty {
                        Text(detail)
                            .font(Theme.FontToken.caption)
                            .foregroundStyle(NellPalette.textSecondary)
                    }
                } else {
                    Text("The profile will be created when onboarding finishes or when you open the coaching profile.")
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.textSecondary)
                }
            } header: {
                Text("Health and training profile")
            } footer: {
                Text("Onboarding writes its confirmed choices into this same profile. Nell Coach reads this profile rather than a separate preference copy.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(NellPalette.groupedBackground)
        .navigationTitle("Personalisation")
    }
}

struct NellAppearanceSettingsView: View {
    @AppStorage("nell.appearance") private var appearance = NellAppearancePreference.system.rawValue

    var body: some View {
        Form {
            Section {
                ForEach(NellAppearancePreference.allCases) { preference in
                    Button {
                        appearance = preference.rawValue
                    } label: {
                        HStack {
                            Label(preference.title, systemImage: preference.symbol)
                                .foregroundStyle(NellPalette.textPrimary)
                            Spacer()
                            if appearance == preference.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(NellPalette.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(appearance == preference.rawValue ? .isSelected : [])
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("System follows the appearance selected for this iPhone.")
            }

            Section("Accessibility") {
                Label("Dynamic Type is supported throughout the Nell component system.", systemImage: "textformat.size")
                Label("Reduce Motion disables decorative motion where implemented.", systemImage: "figure.walk.motion")
            }
        }
        .scrollContentBackground(.hidden)
        .background(NellPalette.groupedBackground)
        .navigationTitle("Appearance")
    }
}

struct NellPrivacySettingsView: View {
    var body: some View {
        Form {
            Section("Local data") {
                Label("Health, nutrition and training records are stored locally by default.", systemImage: "iphone")
                Label("Connected service keys are stored in the device Keychain.", systemImage: "key.horizontal")
            }

            Section("Apple Health") {
                Text("Apple Health access is optional. Nell requests permission through iOS and uses compact summaries for the daily overview and Coach context.")
                Text("Permissions can be changed at any time in the Health app or iPhone Settings.")
            }

            Section("Health and safety") {
                Text("Nell does not diagnose, prescribe treatment, or replace a physician, physiotherapist, dietitian, or other qualified professional.")
                Text("Do not rely on Nell for emergencies or urgent health decisions.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(NellPalette.groupedBackground)
        .navigationTitle("Privacy and Safety")
    }
}

struct NellAboutView: View {
    var body: some View {
        NellScreen {
            NellBrandLockup(showsDescriptor: true)

            NellCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(NellBrand.appStoreTitle)
                        .font(Theme.FontToken.cardTitle)
                        .foregroundStyle(NellPalette.textPrimary)

                    Text("Nell combines optional health summaries with user-confirmed logs, training plans and conversational guidance.")
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                }
            }

            NellCoachSuggestionCard(
                title: "Product principle",
                message: "Show recorded facts clearly, label uncertainty, and require confirmation before writing structured health information."
            )
        }
        .navigationTitle("About Nell")
        .navigationBarTitleDisplayMode(.inline)
    }
}
