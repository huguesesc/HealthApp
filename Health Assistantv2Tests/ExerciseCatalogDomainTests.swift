import Foundation
import Testing
@testable import Health_Assistantv2

struct ExerciseCatalogDomainTests {
    @Test func definitionDecodesRepresentativeRecordWithEmptyInstructions() throws {
        let json = """
        {
          "id": "barbell.back_squat",
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

        #expect(definition.id.rawValue == "barbell.back_squat")
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
          "id": "machine.row",
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

    @Test func exerciseIDAcceptsStableDotIDsAndRejectsMalformedValues() {
        let validIDs = [
            "bodyweight.dead_bug",
            "machine.leg_press",
            "bodyweight.copenhagen_plank.short_lever"
        ]
        let malformedIDs = [
            "barbell-back-squat",
            "bodyweight..dead_bug",
            "bodyweight.dead-bug",
            "Bodyweight.dead_bug",
            "bodyweight.dead_bug.extra.variant"
        ]

        for rawValue in validIDs {
            #expect(ExerciseID(rawValue: rawValue)?.rawValue == rawValue)
        }
        for rawValue in malformedIDs {
            #expect(ExerciseID(rawValue: rawValue) == nil)
        }
    }

    @Test func exerciseIDUsesThirdSegmentForDistinctMechanicsOrMaterialVariantWhileSideIsSessionMetadata() {
        let identifier = ExerciseID(rawValue: "bodyweight.copenhagen_plank.short_lever")

        #expect(identifier?.rawValue == "bodyweight.copenhagen_plank.short_lever")
    }

    @Test func exerciseIDDecodingRejectsMalformedJSONValue() throws {
        let json = "\"machine-leg-press\""

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                ExerciseID.self,
                from: try #require(json.data(using: .utf8))
            )
        }
    }

    @Test func exerciseIDCodableRoundTripsExactlyWithEquality() throws {
        let identifier = try #require(ExerciseID(rawValue: "machine.leg_press"))

        let encoded = try JSONEncoder().encode(identifier)
        let decoded = try JSONDecoder().decode(ExerciseID.self, from: encoded)

        #expect(decoded == identifier)
        #expect(decoded.rawValue == "machine.leg_press")
    }

    @Test func definitionDecodesLegacyIDsAsStableIdentifiers() throws {
        let json = """
        {
          "id": "machine.leg_press",
          "schemaVersion": 1,
          "displayName": "Machine Leg Press",
          "category": "strength",
          "movementPattern": "squat",
          "exerciseType": "compound",
          "equipment": {
            "required": [],
            "alternatives": []
          },
          "trackingMode": "sets-reps",
          "instructions": [],
          "aliases": ["Leg Press"],
          "legacyIDs": ["machine.angled_leg_press", "plate_loaded.leg_press"],
          "lifecycle": {
            "status": "deprecated",
            "replacementExerciseID": "machine.leg_press"
          }
        }
        """

        let definition = try JSONDecoder().decode(
            ExerciseDefinition.self,
            from: try #require(json.data(using: .utf8))
        )

        let expectedLegacyIDs = [
            try #require(ExerciseID(rawValue: "machine.angled_leg_press")),
            try #require(ExerciseID(rawValue: "plate_loaded.leg_press"))
        ]
        let expectedReplacementID = try #require(ExerciseID(rawValue: "machine.leg_press"))

        #expect(definition.aliases == ["Leg Press"])
        #expect(definition.legacyIDs == expectedLegacyIDs)
        #expect(definition.lifecycle.replacementExerciseID == expectedReplacementID)
    }

    @Test func lifecycleStatusDecodingAcceptsOnlyControlledValues() throws {
        let knownStatuses = ["active", "deprecated", "disabled"]

        for rawValue in knownStatuses {
            let decoded = try JSONDecoder().decode(
                ExerciseLifecycleStatus.self,
                from: try #require("\"\(rawValue)\"".data(using: .utf8))
            )
            #expect(decoded.rawValue == rawValue)
        }

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                ExerciseLifecycleStatus.self,
                from: try #require("\"archived\"".data(using: .utf8))
            )
        }
    }
}
