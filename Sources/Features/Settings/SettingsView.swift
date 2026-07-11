import SwiftData
import SwiftUI

/// Lets the user paste their Claude API key, stored in the iOS Keychain via
/// `APIKeyStore`. This is what flips `AIClientFactory` from the offline stub to the
/// real `ClaudeAIClient` (M2). The key is never written to source or plist files.
///
/// BYOK (bring-your-own-key) is the dev / early-user model: the key is the user's own
/// Anthropic API key (console.anthropic.com, pay-per-use) — not a Claude.ai
/// subscription. A backend proxy replaces this for real users later, swapped in behind
/// `AIClientFactory` with no change here.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

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
            Section("Profile & coaching") {
                NavigationLink {
                    ProfileView()
                } label: {
                    Label("Health and training profile", systemImage: "person.crop.circle")
                }

                NavigationLink {
                    WorkoutLocationsView()
                } label: {
                    Label("Workout locations & equipment", systemImage: "mappin.and.ellipse")
                }
            }

            Section("Claude API key") {
                SecureField("sk-ant-…", text: $draftKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Save key") { save() }
                    .disabled(trimmedKey.isEmpty)

                if hasStoredKey {
                    Button("Clear key", role: .destructive) { clear() }
                }
            }

            Section {
                Label(
                    hasStoredKey ? "A key is saved on this device." : "No key saved yet.",
                    systemImage: hasStoredKey ? "checkmark.seal" : "exclamationmark.triangle"
                )
                .foregroundStyle(hasStoredKey ? Color.green : Color.secondary)

                if justSaved {
                    Text("Saved.")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } footer: {
                Text(
                    "Get a key at console.anthropic.com → API Keys. Usage is billed to "
                        + "your own Anthropic account. The key is stored only in this "
                        + "device's Keychain, never in the app's files."
                )
            }

            Section {
                Label(
                    healthKit.isAvailable ? "Available on this device." : "Not available on this device.",
                    systemImage: healthKit.isAvailable ? "heart.text.square" : "exclamationmark.triangle"
                )
                .foregroundStyle(healthKit.isAvailable ? Color.secondary : Theme.clay)

                Button("Connect Apple Health") {
                    connectAppleHealth()
                }
                .disabled(!healthKit.isAvailable || isHealthSyncing)

                Button("Sync Apple Health") {
                    syncAppleHealth()
                }
                .disabled(!healthKit.isAvailable || isHealthSyncing)

                if isHealthSyncing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Syncing...")
                    }
                }

                Text(healthStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Apple Health")
            } footer: {
                Text(
                    "The app reads Apple Health activity, workouts, sleep and heart "
                        + "summaries for personal coaching. Raw HealthKit samples stay on "
                        + "device; only compact daily summaries are used by the assistant."
                )
            }
        }
        .navigationTitle("Settings")
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
        healthStatus = "Requesting Apple Health permission..."
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
        healthStatus = "Syncing recent Apple Health data..."
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
