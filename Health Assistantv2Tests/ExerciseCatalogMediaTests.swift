import Foundation
import Testing
@testable import Health_Assistantv2

struct ExerciseCatalogMediaTests {
    @Test func compositeMediaWithAccessibilityDescriptionIsValid() {
        let media = [
            ExerciseMediaDefinition(
                key: "bodyweight.dead_bug.composite",
                role: .composite,
                sequence: nil,
                variant: nil,
                appearance: nil,
                accessibilityDescription: "A complete dead bug repetition."
            )
        ]

        #expect(media.validationErrors().isEmpty)
    }

    @Test func startAndEndPairIsValid() {
        let media = [
            media("squat.start", role: .start, sequence: 1),
            media("squat.end", role: .end, sequence: 2)
        ]

        #expect(media.validationErrors().isEmpty)
    }

    @Test func primaryAndAlternateSequencesUseSeparateNamespaces() {
        let media = [
            media("lunge.start", role: .start, sequence: 1),
            media("lunge.mid", role: .mid, sequence: 2),
            media("lunge.end", role: .end, sequence: 3),
            media("lunge.alternate.one", role: .alternate, sequence: 1, variant: "kneeling"),
            media("lunge.alternate.two", role: .alternate, sequence: 2, variant: "kneeling")
        ]

        #expect(media.validationErrors().isEmpty)
    }

    @Test func sequenceGapsAndDuplicatesAreInvalid() {
        let media = [
            media("row.start", role: .start, sequence: 1),
            media("row.mid", role: .mid, sequence: 3),
            media("row.end", role: .end, sequence: 3)
        ]

        let errors = media.validationErrors()

        #expect(errors.contains(.duplicateSequence(namespace: .primary, sequence: 3)))
        #expect(errors.contains(.nonContiguousSequence(
            namespace: .primary,
            expected: [1, 2, 3],
            actual: [1, 3]
        )))
    }

    @Test func zeroAndNegativeSequencesAreInvalid() {
        let media = [
            media("press.start", role: .start, sequence: 0),
            media("press.end", role: .end, sequence: -1)
        ]

        let errors = media.validationErrors()

        #expect(errors.contains(.nonPositiveSequence(key: "press.start", sequence: 0)))
        #expect(errors.contains(.nonPositiveSequence(key: "press.end", sequence: -1)))
    }

    @Test func compositeDoesNotSatisfyMissingStartOrEnd() {
        let media = [
            media("bridge.start", role: .start, sequence: 1),
            media("bridge.composite", role: .composite)
        ]

        #expect(media.validationErrors().contains(.missingPairedRole(role: .end)))
    }

    @Test func duplicateKeysAndBlankAccessibilityDescriptionsAreInvalid() {
        let media = [
            media("plank.still", role: .thumbnail, accessibilityDescription: "   "),
            media(" plank.still ", role: .setup),
            media("   ", role: .mistake)
        ]

        let errors = media.validationErrors()

        #expect(errors.contains(.duplicateKey(key: "plank.still")))
        #expect(errors.contains(.blankAccessibilityDescription(key: "plank.still")))
        #expect(errors.contains(.blankKey(key: "   ")))
    }

    private func media(
        _ key: String,
        role: ExerciseMediaRole,
        sequence: Int? = nil,
        variant: String? = nil,
        appearance: ExerciseMediaAppearance? = nil,
        accessibilityDescription: String = "Exercise media."
    ) -> ExerciseMediaDefinition {
        ExerciseMediaDefinition(
            key: key,
            role: role,
            sequence: sequence,
            variant: variant,
            appearance: appearance,
            accessibilityDescription: accessibilityDescription
        )
    }
}
