import SwiftData
import SwiftUI

/// Configuration only. Product destinations such as workout plans, active sessions,
/// history and movement feedback live in the Train tab.
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
            Section("Profile") {
                NavigationLink {
                    ProfileView()
                } label: {
                    Label("Health and training profile", systemImage: "person.crop.circle")
                }

                NavigationLink {
                    WorkoutLocationsView()
                } label: {
                    Label("Equipment and locations", systemImage: "mappin.and.ellipse")
                }
            }

            Section("Coach connection") {
                SecureField("sk-ant-…", text: $draftKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Save key") { save() }
                    .disabled(trimmedKey.isEmpty)

                if hasStoredKey {
                    Label("A key is saved on this device.", systemImage: "checkmark.seal")
                        .foregroundStyle(Color.green)
                    Button("Clear key", role: .destructive) { clear() }
                } else {
                    Label("No key saved yet.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }

                if justSaved {
                    Text("Saved.")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } footer: {
                Text(
                    "Get a key at console.anthropic.com → API Keys. Usage is billed to "
                        + "your Anthropic account. The key is stored in this device's "
                        + "Keychain, never in Nell's files."
                )
            }

            Section {
                Label(
                    healthKit.isAvailable ? "Available on this device." : "Not available on this device.",
                    systemImage: healthKit.isAvailable ? "heart.text.square" : "exclamationmark.triangle"
                )
                .foregroundStyle(healthKit.isAvailable ? Color.secondary : Theme.ColorToken.destructive)

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
                        Text("Syncing…")
                    }
                }

                Text(healthStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Apple Health")
            } footer: {
                Text(
                    "Nell reads Apple Health activity, workouts, sleep and heart "
                        + "summaries for personal coaching. Raw HealthKit samples stay on "
                        + "device; only compact daily summaries are used by the Coach."
                )
            }

            Section("About and privacy") {
                Label("Your health data remains stored locally by default.", systemImage: "lock.shield")
                Text("Nell does not diagnose or replace professional care.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ColorToken.backgroundSecondary)
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
