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
    @State private var draftKey = ""
    @State private var hasStoredKey = APIKeyStore.read()?.isEmpty == false
    @State private var justSaved = false

    var body: some View {
        Form {
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
}

#Preview {
    NavigationStack { SettingsView() }
}
