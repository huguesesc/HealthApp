import Foundation
import Testing
@testable import Health_Assistantv2

@MainActor
struct AdaptiveCoachAssistantToolTests {
    @Test func readOnlyCoachToolsAreRegistered() {
        let names = Set(ChatEngine.tools.map(\.name))

        #expect(names.contains("get_health_profile"))
        #expect(names.contains("get_workout_locations"))
        #expect(names.contains("propose_meal"))
        #expect(names.contains("propose_workout"))
        #expect(names.contains("get_recent_summaries"))
    }

    @Test func coachToolsHaveEmptyReadOnlyInputSchemas() throws {
        let profileTool = try #require(
            ChatEngine.tools.first { $0.name == "get_health_profile" }
        )
        let locationsTool = try #require(
            ChatEngine.tools.first { $0.name == "get_workout_locations" }
        )

        let profileSchema = try #require(
            try JSONSerialization.jsonObject(with: Data(profileTool.inputSchemaJSON.utf8))
                as? [String: Any]
        )
        let locationsSchema = try #require(
            try JSONSerialization.jsonObject(with: Data(locationsTool.inputSchemaJSON.utf8))
                as? [String: Any]
        )

        #expect(profileSchema["type"] as? String == "object")
        #expect(locationsSchema["type"] as? String == "object")
        #expect((profileSchema["properties"] as? [String: Any])?.isEmpty == true)
        #expect((locationsSchema["properties"] as? [String: Any])?.isEmpty == true)
    }

    @Test func systemPromptKeepsUserReportsSeparateFromDiagnosis() {
        #expect(ChatEngine.systemPrompt.contains("user's own reports"))
        #expect(ChatEngine.systemPrompt.contains("never diagnose"))
        #expect(ChatEngine.systemPrompt.contains("never infer a condition"))
    }
}
