import Foundation

/// FUTURE: voice logging. The plan is to transcribe on-device with Apple's free
/// `Speech` framework (`SFSpeechRecognizer`) — cheap and private — then feed the
/// text into `AIClient.parseWorkout` / `parseMeal`. Not implemented tonight.
protocol VoiceTranscriber {
    func transcribe(audioFileURL: URL) async throws -> String
}

/// Placeholder so the seam exists and compiles. Replace with an Apple Speech
/// implementation when voice logging is built.
struct StubVoiceTranscriber: VoiceTranscriber {
    func transcribe(audioFileURL: URL) async throws -> String {
        throw AIClientError.notImplemented
    }
}
