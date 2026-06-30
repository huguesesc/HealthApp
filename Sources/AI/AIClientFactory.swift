import Foundation

/// Vends the app's AI client. Stub by default, so the app always works offline with
/// no key. Switching to the real Claude client is a deliberate, single-line opt-in
/// (M2) — not something that happens implicitly just because a key exists.
///
/// FUTURE / BACKEND: when premium or metered features arrive, return a client that
/// targets your own proxy here instead of `ClaudeAIClient`. Everything upstream of
/// this factory is provider-agnostic, so nothing else changes.
enum AIClientFactory {
    static func makeDefault() -> AIClient {
        // M2: use the real Claude client once the user has stored a key; otherwise
        // stay on the offline stub so the app always works with no key / no network.
        guard let key = APIKeyStore.read(), !key.isEmpty else { return StubAIClient() }
        return ClaudeAIClient()
    }
}
