import SwiftData
import SwiftUI

/// Configuration only. Product destinations such as plans, active sessions,
/// history and progress remain in the Train tab.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("nell.onboarding.completed") private var onboardingComplete = false

    @State private var draftKey = ""
    @State private var hasStoredKey = APIKeyStore.read()?.isEmpty == false
    @State private var justSaved = false
    @State private var isHealthSyncing = false
    @State private var healthStatus = "Not connected yet."

    private let healthKit = HealthKitService()

    private var repo: HealthDataRepository {
        HealthDataRepository(context: modelContext)
    }

    var body: some View {
        Form {
            profileSection
            experienceSection
            coachConnectionSection
            appleHealthSection
            privacySection
        }
        .scrollContentBackground(.hidden)
        .background(NellPalette.groupedBackground)
        .navigationTitle("Settings")
    }

    private var profileSection: some View {
        Section("Profile and goals") {
            NavigationLink {
                NellProfilePreferencesView()
            } label: {
                Label("Personalisation and profile", systemImage: "person.crop.circle")
            }

            NavigationLink {
                WorkoutLocationsView()
            } label: {
                Label("Equipment and locations", systemImage: "mappin.and.ellipse")
            }
        }
    }

    private var experienceSection: some View {
        Section("App experience") {
            NavigationLink {
                NellAppearanceSettingsView()
            } label: {
                Label("Appearance and accessibility", systemImage: "circle.lefthalf.filled")
            }

            Button {
                onboardingComplete = false
            } label: {
                Label("Show first-run setup again", systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var coachConnectionSection: some View {
        Section {
            SecureField("sk-ant-…", text: $draftKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Save key", action: save)
                .disabled(trimmedKey.isEmpty)

            if hasStoredKey {
                Label("A key is saved on this device.", systemImage: "checkmark.seal")
                    .foregroundStyle(NellPalette.primary)
                Button("Clear key", role: .destructive, action: clear)
            } else {
                Label("No key saved yet.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(NellPalette.textSecondary)
            }

            if justSaved {
                Text("Saved.")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.primary)
            }
        } header: {
            Text("Coach connection")
        } footer: {
            Text(
                "A connected Coach key is optional. Usage is billed to your service account. "
                    + "The key is stored in this device's Keychain, never in Nell's files."
            )
        }
    }

    private var appleHealthSection: some View {
        Section {
            Label(
                healthKit.isAvailable ? "Available on this device." : "Not available on this device.",
                systemImage: healthKit.isAvailable ? "heart.text.square" : "exclamationmark.triangle"
            )
            .foregroundStyle(healthKit.isAvailable ? NellPalette.textSecondary : NellPalette.destructive)

            Button("Connect Apple Health", action: connectAppleHealth)
                .disabled(!healthKit.isAvailable || isHealthSyncing)

            Button("Sync Apple Health", action: syncAppleHealth)
                .disabled(!healthKit.isAvailable || isHealthSyncing)

            if isHealthSyncing {
                HStack(spacing: Theme.Spacing.xs) {
                    ProgressView()
                    Text("Syncing…")
                }
            }

            Text(healthStatus)
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textSecondary)
        } header: {
            Text("Apple Health")
        } footer: {
            Text(
                "Nell reads Apple Health activity, workouts, sleep and heart summaries for personal coaching. "
                    + "Raw HealthKit samples stay on device; only compact daily summaries are used by the Coach."
            )
        }
    }

    private var privacySection: some View {
        Section("Privacy, safety and product") {
            NavigationLink {
                NellPrivacySettingsView()
            } label: {
                Label("Privacy and safety", systemImage: "lock.shield")
            }

            NavigationLink {
                NellAboutView()
            } label: {
                Label("About Nell", systemImage: "info.circle")
            }

            Text("Nell does not diagnose or replace professional care.")
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }

    private var trimmedKey: String {
        draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let key = trimmedKey
        guard !key.isEmpty else { return }
        APIKeyStore.save(key)
        draftKey = ""
        hasStoredKey = true
        justSaved = true
    }

    private func clear() {
        APIKeyStore.clear()
        hasStoredKey = false
        justSaved = false
    }

    private func connectAppleHealth() {
        isHealthSyncing = true
        healthStatus = "Requesting Apple Health permission…"
        Task { @MainActor in
            do {
                try await healthKit.requestAuthorization()
                healthStatus = "Connected. Tap Sync Apple Health to import recent data."
            } catch {
                healthStatus = Self.describeHealthError(error)
            }
            isHealthSyncing = false
        }
    }

    private func syncAppleHealth() {
        isHealthSyncing = true
        healthStatus = "Syncing recent Apple Health data…"
        Task { @MainActor in
            do {
                try await healthKit.requestAuthorization()
                let imports = try await healthKit.fetchDailyImports(days: 30)
                repo.applyHealthImports(imports)
                _ = repo.refreshTodayRollup()
                healthStatus = imports.isEmpty
                    ? "Connected, but no recent Apple Health data was found."
                    : "Synced \(imports.count) day(s) from Apple Health."
            } catch {
                healthStatus = Self.describeHealthError(error)
            }
            isHealthSyncing = false
        }
    }

    private static func describeHealthError(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "Could not sync Apple Health. Check permissions in the Health app."
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(PersistenceController.preview.container)
}
