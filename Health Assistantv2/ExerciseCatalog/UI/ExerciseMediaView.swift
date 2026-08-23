import SwiftUI
import UIKit

enum ExerciseMediaPresentation: Sendable {
    case compact
    case hero
}

struct ExerciseMediaPage: Equatable, Identifiable, Sendable {
    let definition: ExerciseMediaDefinition
    let assetName: String

    var id: String { definition.key }
}

enum ExerciseMediaContent: Equatable, Sendable {
    case pages([ExerciseMediaPage])
    case fallback
}

enum ExerciseMediaPresentationModel {
    static func makeContent(
        media: [ExerciseMediaDefinition]?,
        presentation: ExerciseMediaPresentation,
        preferredAppearance: ExerciseMediaAppearance,
        resolver: any ExerciseMediaResolving,
        assetExists: (String) -> Bool
    ) -> ExerciseMediaContent {
        let pages = (media ?? [])
            .filter { item in
                item.appearance == nil || item.appearance == preferredAppearance
            }
            .compactMap { item -> ExerciseMediaPage? in
                guard let assetName = resolver.assetName(for: item.key),
                      assetExists(assetName) else {
                    return nil
                }
                return ExerciseMediaPage(definition: item, assetName: assetName)
            }
            .sorted { orderedBefore($0, $1, presentation: presentation) }

        guard !pages.isEmpty else {
            return .fallback
        }
        switch presentation {
        case .compact:
            return .pages([pages[0]])
        case .hero:
            return .pages(pages)
        }
    }

    private static func orderedBefore(
        _ lhs: ExerciseMediaPage,
        _ rhs: ExerciseMediaPage,
        presentation: ExerciseMediaPresentation
    ) -> Bool {
        switch presentation {
        case .compact:
            let lhsRole = compactPriority(lhs.definition.role)
            let rhsRole = compactPriority(rhs.definition.role)
            if lhsRole != rhsRole { return lhsRole < rhsRole }
        case .hero:
            let lhsHasSequence = lhs.definition.sequence != nil
            let rhsHasSequence = rhs.definition.sequence != nil
            if lhsHasSequence != rhsHasSequence { return lhsHasSequence }
        }

        let lhsSequence = lhs.definition.sequence ?? Int.max
        let rhsSequence = rhs.definition.sequence ?? Int.max
        if lhsSequence != rhsSequence { return lhsSequence < rhsSequence }

        let lhsRole = instructionalPriority(lhs.definition.role)
        let rhsRole = instructionalPriority(rhs.definition.role)
        if lhsRole != rhsRole { return lhsRole < rhsRole }

        let lhsVariant = lhs.definition.variant ?? ""
        let rhsVariant = rhs.definition.variant ?? ""
        if lhsVariant != rhsVariant { return lhsVariant < rhsVariant }
        return lhs.definition.key < rhs.definition.key
    }

    private static func compactPriority(_ role: ExerciseMediaRole) -> Int {
        switch role {
        case .thumbnail: 0
        case .composite: 1
        case .setup: 2
        case .start: 3
        case .correct: 4
        case .mid: 5
        case .end: 6
        case .alternate: 7
        case .mistake: 8
        }
    }

    private static func instructionalPriority(_ role: ExerciseMediaRole) -> Int {
        switch role {
        case .thumbnail: 0
        case .setup: 1
        case .start: 2
        case .mid: 3
        case .end: 4
        case .composite: 5
        case .correct: 6
        case .mistake: 7
        case .alternate: 8
        }
    }
}

struct ExerciseMediaView: View {
    let media: [ExerciseMediaDefinition]?
    let fallbackTitle: String
    var presentation: ExerciseMediaPresentation = .hero

    private let resolver: any ExerciseMediaResolving
    private let imageLoader: (String) -> UIImage?

    @Environment(\.colorScheme) private var colorScheme

    init(
        media: [ExerciseMediaDefinition]?,
        fallbackTitle: String,
        presentation: ExerciseMediaPresentation = .hero,
        resolver: any ExerciseMediaResolving,
        bundle: Bundle = .main
    ) {
        self.media = media
        self.fallbackTitle = fallbackTitle
        self.presentation = presentation
        self.resolver = resolver
        self.imageLoader = { name in
            UIImage(named: name, in: bundle, compatibleWith: nil)
        }
    }

    var body: some View {
        switch content {
        case .pages(let pages):
            pageContent(pages)
        case .fallback:
            fallbackContent
        }
    }

    private var content: ExerciseMediaContent {
        ExerciseMediaPresentationModel.makeContent(
            media: media,
            presentation: presentation,
            preferredAppearance: colorScheme == .dark ? .dark : .light,
            resolver: resolver,
            assetExists: { imageLoader($0) != nil }
        )
    }

    @ViewBuilder
    private func pageContent(_ pages: [ExerciseMediaPage]) -> some View {
        if pages.count == 1, let page = pages.first {
            image(for: page, pageNumber: nil, pageCount: 1)
                .frame(maxWidth: .infinity, maxHeight: maximumHeight)
        } else {
            TabView {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    image(for: page, pageNumber: index + 1, pageCount: pages.count)
                        .padding(.bottom, Theme.Spacing.sm)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(maxWidth: .infinity)
            .frame(height: maximumHeight)
        }
    }

    @ViewBuilder
    private func image(
        for page: ExerciseMediaPage,
        pageNumber: Int?,
        pageCount: Int
    ) -> some View {
        if let image = imageLoader(page.assetName) {
            Image(uiImage: image)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(page.definition.accessibilityDescription)
                .accessibilityValue(pageValue(number: pageNumber, count: pageCount))
        } else {
            fallbackContent
        }
    }

    private var fallbackContent: some View {
        VStack(spacing: Theme.Spacing.xs) {
            WorkoutMotionView(
                title: fallbackTitle,
                presentation: fallbackMotionPresentation
            )
            .frame(maxWidth: .infinity)
            .frame(height: fallbackHeight)

            Text("Exercise illustration unavailable")
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(fallbackTitle). Exercise illustration unavailable. Follow the written instructions."
        )
    }

    private var maximumHeight: CGFloat {
        switch presentation {
        case .compact: 96
        case .hero: 320
        }
    }

    private var fallbackHeight: CGFloat {
        switch presentation {
        case .compact: 70
        case .hero: 180
        }
    }

    private var fallbackMotionPresentation: WorkoutMotionPresentation {
        switch presentation {
        case .compact: .compact
        case .hero: .pair
        }
    }

    private func pageValue(number: Int?, count: Int) -> String {
        guard let number, count > 1 else { return "" }
        return "Page \(number) of \(count)"
    }
}

#Preview("Exercise media") {
    let media = ExerciseMediaDefinition(
        key: "bodyweight.squat__composite",
        role: .composite,
        sequence: nil,
        variant: nil,
        appearance: nil,
        accessibilityDescription: "Two poses demonstrate a bodyweight squat."
    )
    let resolver = DictionaryExerciseMediaResolver(
        assetNamesByKey: [media.key: "bodyweight.squat__composite"]
    )

    ScrollView {
        VStack(spacing: Theme.Spacing.xl) {
            ExerciseMediaView(
                media: [media],
                fallbackTitle: "Bodyweight Squat",
                resolver: resolver
            )
            ExerciseMediaView(
                media: [media],
                fallbackTitle: "Bodyweight Squat",
                presentation: .compact,
                resolver: DictionaryExerciseMediaResolver(assetNamesByKey: [:])
            )
        }
        .padding()
    }
    .background(NellPalette.background)
}
