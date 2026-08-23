import Foundation
import Testing
@testable import Health_Assistantv2

/// Pins legacy-name compatibility decisions from
/// docs/nell-redesign/exercise-catalog/LEGACY_EXERCISE_NAME_AUDIT.md against
/// the real checked-in catalogue so alias regressions surface immediately.
struct LegacyNameCompatibilityTests {
    private let resolver: LegacyExerciseResolver

    init() throws {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let resourceURL = testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json"
            )
        let manifest = try JSONDecoder().decode(
            ExerciseCatalogManifest.self,
            from: Data(contentsOf: resourceURL)
        )
        resolver = LegacyExerciseResolver(definitions: manifest.exercises)
    }

    private func resolvedID(_ reference: String) -> String? {
        if case .resolved(let definition, _) = resolver.resolve(reference) {
            return definition.id.rawValue
        }
        return nil
    }

    @Test func harvestedRegistryNamesResolveThroughExactNormalization() {
        #expect(resolvedID("Goblet squat") == "dumbbell.goblet_squat")
        #expect(resolvedID("goblet_squat") == "dumbbell.goblet_squat")
        #expect(resolvedID("Bent-over row") == "dumbbell.bent_over_row")
        #expect(resolvedID("bent over row") == "dumbbell.bent_over_row")
        #expect(resolvedID("Dumbbell row") == "dumbbell.bent_over_row")
        #expect(resolvedID("Forward lunge") == "bodyweight.forward_lunge")
        #expect(resolvedID("Bodyweight SQUAT!!") == "bodyweight.squat")
    }

    @Test func compatibilityAliasesAddedFromLegacyAuditResolveExactly() {
        #expect(resolvedID("Air squat") == "bodyweight.squat")
        #expect(resolvedID("Overhead press") == "dumbbell.overhead_press")
        #expect(resolvedID("Shoulder press") == "dumbbell.overhead_press")
        #expect(resolvedID("RDL") == "barbell.romanian_deadlift")
        #expect(resolvedID("rdl!") == "barbell.romanian_deadlift")
        #expect(resolvedID("Romanian Deadlift.") == "barbell.romanian_deadlift")
        #expect(resolvedID("Barbell RDL") == "barbell.romanian_deadlift")
        #expect(resolvedID("Deadlift") == "barbell.deadlift")
    }

    @Test func deliberatelyAmbiguousBareTermsStayFreeForm() {
        #expect(resolvedID("squat") == nil)
        #expect(resolvedID("row") == nil)
        #expect(resolvedID("lunge") == nil)
        #expect(resolvedID("reverse lunge") == nil)
        #expect(resolvedID("plank") == nil)
        #expect(resolvedID("hip hinge") == nil)
        #expect(resolvedID("tree pose") == nil)
        #expect(resolvedID("military press") == nil)
        #expect(resolvedID("dumbbell press") == nil)
        #expect(resolvedID("TKE") == nil)
    }

    @Test func misspelledDumbellStaysUnresolvedUntilLegacyNameIsSeeded() {
        // Production data intentionally seeds no hidden legacy names yet;
        // the resolution mechanism itself is covered by
        // GeneratedWorkoutValidatorTests using injected fixtures.
        #expect(resolvedID("dumbell biceps curl") == nil)
    }

    @Test func everyCatalogueEntryRemainsReachableByItsOwnDisplayName() throws {
        let manifest = try JSONDecoder().decode(
            ExerciseCatalogManifest.self,
            from: Data(contentsOf: catalogueURL())
        )
        for exercise in manifest.exercises {
            #expect(resolvedID(exercise.displayName) == exercise.id.rawValue)
        }
    }

    private func catalogueURL() -> URL {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        return testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json"
            )
    }
}
