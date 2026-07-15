import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Health_Assistantv2

struct ExerciseMediaResolverTests {
    @Test func bundledIndexResolvesOnlyExactMediaKeys() throws {
        let resolver = try BundledExerciseMediaResolver(data: indexData())

        #expect(resolver.assetName(for: "squat.composite") == "bodyweight.squat__composite")
        #expect(resolver.assetName(for: "SQUAT.COMPOSITE") == nil)
        #expect(resolver.assetName(for: "squat") == nil)
    }

    @Test func malformedUnsupportedAndDuplicateIndexesFailClosed() throws {
        #expect(throws: DecodingError.self) {
            try BundledExerciseMediaResolver(data: Data("not-json".utf8))
        }

        #expect(throws: ExerciseMediaResolverError.unsupportedSchemaVersion(2)) {
            try BundledExerciseMediaResolver(data: indexData(schemaVersion: 2))
        }

        #expect(throws: ExerciseMediaResolverError.duplicateKey("squat.composite")) {
            try BundledExerciseMediaResolver(
                data: indexData(entries: [
                    ("squat.composite", "first"),
                    ("squat.composite", "second")
                ])
            )
        }
    }

    @Test func missingBundledIndexHasAnExplicitTypedError() throws {
        #expect(throws: ExerciseMediaResolverError.resourceNotFound("missing-media-index.json")) {
            try BundledExerciseMediaResolver(
                bundle: .main,
                resourceName: "missing-media-index"
            )
        }
    }

    @Test func compactPresentationPrefersOneThumbnailThenComposite() {
        let media = [
            item("squat.end", role: .end, sequence: 2),
            item("squat.composite", role: .composite),
            item("squat.thumbnail", role: .thumbnail),
            item("squat.start", role: .start, sequence: 1)
        ]
        let resolver = DictionaryExerciseMediaResolver(
            assetNamesByKey: Dictionary(uniqueKeysWithValues: media.map { ($0.key, $0.key) })
        )

        let content = ExerciseMediaPresentationModel.makeContent(
            media: media,
            presentation: .compact,
            preferredAppearance: .light,
            resolver: resolver,
            assetExists: { _ in true }
        )

        #expect(content == .pages([
            ExerciseMediaPage(definition: media[2], assetName: "squat.thumbnail")
        ]))
    }

    @Test func heroPresentationOrdersFramesAndFiltersAppearance() {
        let darkComposite = item(
            "squat.dark",
            role: .composite,
            appearance: .dark
        )
        let media = [
            item("squat.end", role: .end, sequence: 3),
            darkComposite,
            item("squat.mid", role: .mid, sequence: 2),
            item("squat.start", role: .start, sequence: 1),
            item("squat.light", role: .composite, appearance: .light)
        ]
        let resolver = DictionaryExerciseMediaResolver(
            assetNamesByKey: Dictionary(uniqueKeysWithValues: media.map { ($0.key, "asset.\($0.key)") })
        )

        let content = ExerciseMediaPresentationModel.makeContent(
            media: media,
            presentation: .hero,
            preferredAppearance: .dark,
            resolver: resolver,
            assetExists: { _ in true }
        )

        #expect(content == .pages([
            ExerciseMediaPage(definition: media[3], assetName: "asset.squat.start"),
            ExerciseMediaPage(definition: media[2], assetName: "asset.squat.mid"),
            ExerciseMediaPage(definition: media[0], assetName: "asset.squat.end"),
            ExerciseMediaPage(definition: darkComposite, assetName: "asset.squat.dark")
        ]))
    }

    @Test func absentIndexKeyOrImageUsesFallbackWithoutCrashing() {
        let media = [
            item("missing.index.key", role: .composite),
            item("missing.image", role: .alternate, sequence: 1)
        ]
        let resolver = DictionaryExerciseMediaResolver(
            assetNamesByKey: ["missing.image": "asset.not.in.catalog"]
        )

        let content = ExerciseMediaPresentationModel.makeContent(
            media: media,
            presentation: .hero,
            preferredAppearance: .light,
            resolver: resolver,
            assetExists: { _ in false }
        )

        #expect(content == .fallback)
        #expect(
            ExerciseMediaPresentationModel.makeContent(
                media: nil,
                presentation: .compact,
                preferredAppearance: .light,
                resolver: resolver,
                assetExists: { _ in true }
            ) == .fallback
        )
    }

    @Test func productionBundleResolvesTheIndexedSquatImage() throws {
        let resolver = try BundledExerciseMediaResolver(bundle: .main)
        let assetName = try #require(
            resolver.assetName(for: "bodyweight.squat__composite")
        )

        #expect(assetName == "bodyweight.squat__composite")
        #expect(UIImage(named: assetName, in: .main, compatibleWith: nil) != nil)
    }

    @Test @MainActor func imageAndFallbackViewsRenderAtAccessibilitySizes() throws {
        let media = item("bodyweight.squat__composite", role: .composite)
        let productionResolver = try BundledExerciseMediaResolver(bundle: .main)
        let renderedMedia = ImageRenderer(
            content: ExerciseMediaView(
                media: [media],
                fallbackTitle: "Bodyweight Squat",
                resolver: productionResolver
            )
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, .accessibility5)
            .frame(width: 320, height: 360)
        )
        let renderedFallback = ImageRenderer(
            content: ExerciseMediaView(
                media: [media],
                fallbackTitle: "Bodyweight Squat",
                presentation: .compact,
                resolver: DictionaryExerciseMediaResolver(assetNamesByKey: [:])
            )
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, .accessibility5)
            .frame(width: 160, height: 140)
        )
        let renderedLightCompact = ImageRenderer(
            content: ExerciseMediaView(
                media: [media],
                fallbackTitle: "Bodyweight Squat",
                presentation: .compact,
                resolver: productionResolver
            )
            .environment(\.colorScheme, .light)
            .frame(width: 160, height: 140)
        )

        #expect(renderedMedia.uiImage != nil)
        #expect(renderedFallback.uiImage != nil)
        #expect(renderedLightCompact.uiImage != nil)
    }

    private func item(
        _ key: String,
        role: ExerciseMediaRole,
        sequence: Int? = nil,
        appearance: ExerciseMediaAppearance? = nil
    ) -> ExerciseMediaDefinition {
        ExerciseMediaDefinition(
            key: key,
            role: role,
            sequence: sequence,
            variant: nil,
            appearance: appearance,
            accessibilityDescription: "Accessible description for \(key)."
        )
    }

    private func indexData(
        schemaVersion: Int = 1,
        entries: [(key: String, assetName: String)] = [
            ("squat.composite", "bodyweight.squat__composite")
        ]
    ) -> Data {
        let media = entries.map {
            "{\"key\":\"\($0.key)\",\"assetName\":\"\($0.assetName)\"}"
        }.joined(separator: ",")
        return Data("{\"schemaVersion\":\(schemaVersion),\"media\":[\(media)]}".utf8)
    }
}
