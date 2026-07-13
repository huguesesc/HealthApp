import Foundation
import Testing
@testable import Health_Assistantv2

struct ExerciseCatalogDomainTests {
    @Test func definitionDecodesRepresentativeRecordWithEmptyInstructions() throws {
        let json = """
        {
          "id": "barbell-back-squat",
          "schemaVersion": 1,
          "displayName": "Barbell Back Squat",
          "category": "strength",
          "movementPattern": "squat",
          "exerciseType": "compound",
          "equipment": {
            "required": [["barbell", "weight-plates"]],
            "alternatives": [["dumbbells"]]
          },
          "trackingMode": "sets-reps",
          "instructions": [],
          "lifecycle": "active"
        }
        """

        let definition = try JSONDecoder().decode(
            ExerciseDefinition.self,
            from: try #require(json.data(using: .utf8))
        )

        #expect(definition.id.rawValue == "barbell-back-squat")
        #expect(definition.displayName == "Barbell Back Squat")
        #expect(definition.category.rawValue == "strength")
        #expect(definition.instructions.isEmpty)
        #expect(definition.lifecycle == .active)
    }

    @Test func categoryRawValueRoundTripsWithEquality() throws {
        let category = ExerciseCategory(rawValue: "strength")

        let encoded = try JSONEncoder().encode(category)
        let decoded = try JSONDecoder().decode(ExerciseCategory.self, from: encoded)

        #expect(decoded == category)
        #expect(decoded.rawValue == "strength")
    }
}
