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
        StubAIClient()
        // To enable real calls in M2:
        //   guard APIKeyStore.read() != nil else { return StubAIClient() }
        //   return ClaudeAIClient()
    }
}
