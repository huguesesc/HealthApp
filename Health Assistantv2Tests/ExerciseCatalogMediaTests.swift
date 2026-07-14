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
            media("lunge.alternate.two", role: .alternate, sequence: 2, variant: "kneeling"),
            media("lunge.alternate.three", role: .alternate, sequence: 1, variant: "supported")
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

    @Test func pairedEndpointsRequireSequences() {
        let media = [
            media("press.start", role: .start),
            media("press.end", role: .end)
        ]

        #expect(media.validationErrors().contains(.missingEndpointSequence(role: .start)))
        #expect(media.validationErrors().contains(.missingEndpointSequence(role: .end)))
    }

    @Test func startMustPrecedeEndInTheInstructionalSequence() {
        let media = [
            media("press.end", role: .end, sequence: 1),
            media("press.start", role: .start, sequence: 2)
        ]

        #expect(media.validationErrors().contains(
            .invalidEndpointOrder(startSequence: 2, endSequence: 1)
        ))
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
        #expect(errors.contains(.keyContainsLeadingOrTrailingWhitespace(key: " plank.still ")))
    }

    @Test func mediaJSONRoundTripsOptionalFieldsCompositeAndInstructionalSequence() throws {
        let json = """
        [
          {
            "key": "squat.thumbnail",
            "role": "thumbnail",
            "accessibilityDescription": "Squat thumbnail."
          },
          {
            "key": "squat.start",
            "role": "start",
            "sequence": 1,
            "variant": "bodyweight",
            "appearance": "light",
            "accessibilityDescription": "Standing at the start of a squat."
          },
          {
            "key": "squat.mid",
            "role": "mid",
            "sequence": 2,
            "accessibilityDescription": "At the bottom of a squat."
          },
          {
            "key": "squat.end",
            "role": "end",
            "sequence": 3,
            "accessibilityDescription": "Standing at the end of a squat."
          },
          {
            "key": "squat.composite",
            "role": "composite",
            "appearance": "dark",
            "accessibilityDescription": "A complete squat repetition."
          }
        ]
        """

        let decoded = try JSONDecoder().decode(
            [ExerciseMediaDefinition].self,
            from: try #require(json.data(using: .utf8))
        )
        let roundTripped = try JSONDecoder().decode(
            [ExerciseMediaDefinition].self,
            from: JSONEncoder().encode(decoded)
        )

        #expect(decoded == roundTripped)
        #expect(decoded.validationErrors().isEmpty)
        #expect(decoded[0].sequence == nil)
        #expect(decoded[0].variant == nil)
        #expect(decoded[0].appearance == nil)
        #expect(decoded[4].role == .composite)
    }

    @Test func invalidEndpointOrderDecodesAndFailsValidation() throws {
        let json = """
        [
          {
            "key": "row.end",
            "role": "end",
            "sequence": 1,
            "accessibilityDescription": "Ending row position."
          },
          {
            "key": "row.start",
            "role": "start",
            "sequence": 2,
            "accessibilityDescription": "Starting row position."
          }
        ]
        """

        let decoded = try JSONDecoder().decode(
            [ExerciseMediaDefinition].self,
            from: try #require(json.data(using: .utf8))
        )

        #expect(decoded.validationErrors().contains(
            .invalidEndpointOrder(startSequence: 2, endSequence: 1)
        ))
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
