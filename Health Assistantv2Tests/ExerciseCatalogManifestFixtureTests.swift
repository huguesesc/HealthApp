import Foundation
import Testing
@testable import Health_Assistantv2

struct ExerciseCatalogManifestFixtureTests {
    @Test func catalogFixtureDecodesTheApprovedInitialExerciseSet() throws {
        let fixture = try loadCatalogFixture()
        let expectedIDs: Set<String> = [
            "bodyweight.squat",
            "bodyweight.dead_bug",
            "bodyweight.push_up",
            "bodyweight.glute_bridge",
            "bodyweight.bird_dog",
            "bodyweight.forward_lunge",
            "bodyweight.calf_raise",
            "bodyweight.side_plank",
            "bodyweight.mountain_climber",
            "bodyweight.jumping_jack",
            "dumbbell.goblet_squat",
            "dumbbell.bent_over_row",
            "dumbbell.biceps_curl",
            "dumbbell.overhead_press",
            "barbell.deadlift",
            "barbell.romanian_deadlift",
            "machine.leg_press",
            "machine.lat_pulldown",
            "cable.triceps_pushdown",
            "band.lateral_squat"
        ]

        #expect(fixture.catalogSchemaVersion == 1)
        #expect(fixture.exercises.count == expectedIDs.count)
        #expect(Set(fixture.exercises.map(\.id.rawValue)) == expectedIDs)
    }

    @Test func catalogFixtureEntriesUseActiveTwoSentenceCompositeRecords() throws {
        let fixture = try loadCatalogFixture()

        for exercise in fixture.exercises {
            #expect(exercise.schemaVersion == 1)
            #expect(exercise.lifecycle.status == .active)
            #expect(exercise.instructions.count == 2)
            #expect(exercise.instructions.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })

            let media = try #require(exercise.media)
            let composite = try #require(media.first)
            #expect(media.count == 1)
            #expect(composite.role == .composite)
            #expect(composite.key == "\(exercise.id.rawValue)__composite")
            #expect(composite.sequence == nil)
            #expect(!composite.accessibilityDescription.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty)
            #expect(media.validationErrors().isEmpty)
        }
    }

    @Test func catalogFixtureReferencesKnownEquipmentAndEnvironmentCapabilities() throws {
        let fixture = try loadCatalogFixture()
        let equipmentTaxonomy = try loadEquipmentTaxonomy()
        let environmentTaxonomy = try loadEnvironmentTaxonomy()
        let equipmentIDs = Set(equipmentTaxonomy.equipment.map(\.id.rawValue))
        let capabilityIDs = Set(environmentTaxonomy.environments.flatMap {
            $0.defaultCapabilities.map(\.rawValue)
        })

        for exercise in fixture.exercises {
            let requirementGroups = [exercise.equipment.required] + exercise.equipment.alternatives
            for requirement in requirementGroups.flatMap({ $0 }) {
                #expect(equipmentIDs.contains(requirement.id.rawValue))
            }

            let requiredEquipment = exercise.equipment.required
            if requiredEquipment.contains(where: { $0.id.rawValue == "none" }) {
                #expect(requiredEquipment.count == 1)
                #expect(requiredEquipment.first?.quantity == 1)
                #expect(exercise.equipment.alternatives.isEmpty)
            }
            #expect(!exercise.equipment.alternatives.flatMap { $0 }.contains {
                $0.id.rawValue == "none"
            })

            let capabilities = (exercise.environmentRequirements?.required ?? [])
                + (exercise.environmentRequirements?.prohibited ?? [])
            for capability in capabilities {
                #expect(capabilityIDs.contains(capability.rawValue))
            }
        }
    }

    @Test func catalogFixtureRecordsAuditedSurfaceAndMovementCapabilities() throws {
        let fixture = try loadCatalogFixture()
        let requiredCapabilitiesByID = Dictionary(uniqueKeysWithValues: fixture.exercises.map {
            exercise in
            (
                exercise.id.rawValue,
                Set(exercise.environmentRequirements?.required.map(\.rawValue) ?? [])
            )
        })
        let floorSpaceExerciseIDs: Set<String> = [
            "bodyweight.dead_bug",
            "bodyweight.push_up",
            "bodyweight.glute_bridge",
            "bodyweight.bird_dog",
            "bodyweight.side_plank",
            "bodyweight.mountain_climber"
        ]
        let standingExerciseIDsWithoutAdditionalCapabilities: Set<String> = [
            "bodyweight.forward_lunge",
            "band.lateral_squat"
        ]
        let lateralSquat = try #require(fixture.exercises.first {
            $0.id.rawValue == "band.lateral_squat"
        })
        let lateralStepInstruction = "Step laterally into a squat, then bring the trailing foot in "
            + "and repeat on the other side."

        for exerciseID in floorSpaceExerciseIDs {
            #expect(requiredCapabilitiesByID[exerciseID] == Set<String>(["floor_space"]))
        }
        #expect(
            requiredCapabilitiesByID["bodyweight.jumping_jack"]
                == Set<String>(["jumping_allowed"])
        )
        for exerciseID in standingExerciseIDsWithoutAdditionalCapabilities {
            #expect(requiredCapabilitiesByID[exerciseID] == Set<String>())
        }
        #expect(lateralSquat.instructions == [
            "Place a mini resistance band above the knees and stand with feet hip-width apart.",
            lateralStepInstruction
        ])
    }

    @Test func catalogFixtureIncludesOnlyExactSafeLegacyMotionAliases() throws {
        let fixture = try loadCatalogFixture()
        let vectorMotionIDs: Set<String> = [
            "goblet_squat",
            "bent_over_row",
            "overhead_press",
            "split_squat",
            "plank_row",
            "hip_hinge",
            "side_stretch",
            "yoga_balance"
        ]
        let matchingAliases: [(alias: String, exerciseID: String)] = fixture.exercises.flatMap {
            exercise in
            (exercise.aliases ?? [])
                .filter { vectorMotionIDs.contains($0) }
                .map { (alias: $0, exerciseID: exercise.id.rawValue) }
        }
        let aliasOwners = Dictionary(grouping: matchingAliases, by: \.alias).mapValues {
            Set($0.map(\.exerciseID))
        }
        let expectedAliasOwners = [
            "goblet_squat": Set(["dumbbell.goblet_squat"]),
            "bent_over_row": Set(["dumbbell.bent_over_row"]),
            "overhead_press": Set(["dumbbell.overhead_press"])
        ]
        let catalogIDs = Set(fixture.exercises.map(\.id.rawValue))
        let allAliases = Set(fixture.exercises.flatMap { $0.aliases ?? [] })
        let unsafeMotionIDs: Set<String> = [
            "split_squat",
            "plank_row",
            "hip_hinge",
            "side_stretch",
            "yoga_balance"
        ]

        #expect(aliasOwners == expectedAliasOwners)
        #expect(!catalogIDs.contains("dumbbell.floor_press"))
        #expect(!allAliases.contains("dumbbell.floor_press"))
        #expect(unsafeMotionIDs.isDisjoint(with: catalogIDs))
        #expect(unsafeMotionIDs.isDisjoint(with: allAliases))
    }

    private func loadCatalogFixture() throws -> ExerciseCatalogFixture {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let resourceURL = testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json"
            )
        return try JSONDecoder().decode(
            ExerciseCatalogFixture.self,
            from: Data(contentsOf: resourceURL)
        )
    }

    private func loadEquipmentTaxonomy() throws -> EquipmentTaxonomy {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let resourceURL = testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Health Assistantv2/ExerciseCatalog/Resources/Authoring/equipment.json"
            )
        return try JSONDecoder().decode(EquipmentTaxonomy.self, from: Data(contentsOf: resourceURL))
    }

    private func loadEnvironmentTaxonomy() throws -> ExerciseEnvironmentTaxonomy {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let resourceURL = testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Health Assistantv2/ExerciseCatalog/Resources/Authoring/environments.json"
            )
        return try JSONDecoder().decode(
            ExerciseEnvironmentTaxonomy.self,
            from: Data(contentsOf: resourceURL)
        )
    }
}

private struct ExerciseCatalogFixture: Decodable {
    let catalogSchemaVersion: Int
    let exercises: [ExerciseDefinition]
}
