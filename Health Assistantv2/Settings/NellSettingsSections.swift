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

struct NellProfilePreferencesView: View {
    @AppStorage("nell.profile.displayName") private var displayName = ""
    @AppStorage("nell.profile.goals") private var goals = ""
    @AppStorage("nell.profile.trainingContext") private var trainingContext = "mixed"
    @AppStorage("nell.profile.movementNotes") private var movementNotes = ""

    var body: some View {
        Form {
            Section("Personalisation") {
                TextField("Preferred name", text: $displayName)
                    .textInputAutocapitalization(.words)

                TextField("Goals", text: $goals, axis: .vertical)
                    .lineLimit(2...4)
            } footer: {
                Text("These values provide context for organisation and Coach responses. They are not medical targets.")
            }

            Section("Training context") {
                Picker("Usual setting", selection: $trainingContext) {
                    Text("Mostly at home").tag("home")
                    Text("Mostly at a gym").tag("gym")
                    Text("Mostly outdoors").tag("outdoors")
                    Text("A mix of settings").tag("mixed")
                }
            }

            Section("Movement considerations") {
                TextField(
                    "Self-reported limitations or movements to avoid",
                    text: $movementNotes,
                    axis: .vertical
                )
                .lineLimit(4...8)
            } footer: {
                Text("Nell does not diagnose injuries. Seek qualified care when pain, instability, swelling, or other concerning symptoms are present.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(NellPalette.groupedBackground)
        .navigationTitle("Nell Profile")
    }
}

struct NellAppearanceSettingsView: View {
    @AppStorage("nell.appearance") private var appearance = NellAppearancePreference.system.rawValue

    var body: some View {
        Form {
            Section("Appearance") {
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
