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
            "required": [
              { "id": "barbell", "quantity": 1 },
              { "id": "weight-plates", "quantity": 2 }
            ],
            "alternatives": [
              [
                { "id": "dumbbell", "quantity": 2 }
              ]
            ]
          },
          "trackingMode": "sets-reps",
          "instructions": [],
          "environmentRequirements": {
            "required": ["machine_access"],
            "prohibited": ["jumping_allowed"]
          },
          "lifecycle": {
            "status": "active"
          }
        }
        """

        let definition = try JSONDecoder().decode(
            ExerciseDefinition.self,
            from: try #require(json.data(using: .utf8))
        )

        #expect(definition.id.rawValue == "barbell-back-squat")
        #expect(definition.displayName == "Barbell Back Squat")
        #expect(definition.category.rawValue == "strength")
        #expect(definition.equipment.required == [
            ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "barbell"), quantity: 1),
            ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "weight-plates"), quantity: 2)
        ])
        #expect(definition.equipment.alternatives == [[
            ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "dumbbell"), quantity: 2)
        ]])
        #expect(definition.instructions.isEmpty)
        let environmentRequirements = try #require(definition.environmentRequirements)
        #expect(environmentRequirements.required == [
            ExerciseEnvironmentRequirement(rawValue: "machine_access")
        ])
        #expect(environmentRequirements.prohibited == [
            ExerciseEnvironmentRequirement(rawValue: "jumping_allowed")
        ])
        #expect(definition.lifecycle.status.rawValue == "active")
        #expect(definition.lifecycle.replacementExerciseID == nil)
    }

    @Test func definitionDecodesRequiredOnlyEnvironmentRequirements() throws {
        let json = """
        {
          "id": "machine-row",
          "schemaVersion": 1,
          "displayName": "Machine Row",
          "category": "strength",
          "movementPattern": "pull",
          "exerciseType": "compound",
          "equipment": {
            "required": [],
            "alternatives": []
          },
          "trackingMode": "sets-reps",
          "instructions": [],
          "environmentRequirements": {
            "required": ["machine_access"]
          },
          "lifecycle": {
            "status": "active"
          }
        }
        """

        let definition = try JSONDecoder().decode(
            ExerciseDefinition.self,
            from: try #require(json.data(using: .utf8))
        )
        let environmentRequirements = try #require(definition.environmentRequirements)

        #expect(environmentRequirements.required == [
            ExerciseEnvironmentRequirement(rawValue: "machine_access")
        ])
        #expect(environmentRequirements.prohibited == nil)
    }

    @Test func categoryRawValueRoundTripsWithEquality() throws {
        let category = ExerciseCategory(rawValue: "strength")

        let encoded = try JSONEncoder().encode(category)
        let decoded = try JSONDecoder().decode(ExerciseCategory.self, from: encoded)

        #expect(decoded == category)
        #expect(decoded.rawValue == "strength")
    }
}
