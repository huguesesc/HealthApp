import SwiftUI

/// Stable style identity for workout figures. Adding a new character pack should
/// require a style registration rather than changes to workout business logic.
struct WorkoutAvatarStyle: Identifiable, Hashable, Sendable {
    let id: String
    let skin: Color
    let hair: Color
    let top: Color
    let bottoms: Color
    let shoes: Color
    let equipment: Color

    static let nellNeutral = WorkoutAvatarStyle(
        id: "nell_neutral_01",
        skin: Color(red: 0.72, green: 0.73, blue: 0.72),
        hair: Color(red: 0.26, green: 0.28, blue: 0.27),
        top: Color(red: 0.48, green: 0.62, blue: 0.49),
        bottoms: Color(red: 0.18, green: 0.34, blue: 0.24),
        shoes: Color(red: 0.90, green: 0.90, blue: 0.87),
        equipment: Color(red: 0.25, green: 0.27, blue: 0.26)
    )
}

enum WorkoutAvatarStyleRegistry {
    static let defaultStyleID = WorkoutAvatarStyle.nellNeutral.id

    private static let styles: [String: WorkoutAvatarStyle] = [
        WorkoutAvatarStyle.nellNeutral.id: .nellNeutral
    ]

    static func style(id: String?) -> WorkoutAvatarStyle {
        guard let id, let style = styles[id] else { return .nellNeutral }
        return style
    }
}

enum WorkoutAvatarEquipment: Hashable, Sendable {
    case none
    case dumbbells
    case gobletWeight
}

enum WorkoutAvatarPose: String, CaseIterable, Hashable, Codable, Sendable {
    case standing
    case gobletSquat
    case hipHinge
    case bentOverRow
    case overheadStart
    case overheadFinish
    case splitSquat
    case plank
    case plankRow
    case sideStretchStart
    case sideStretchFinish
    case treeBalanceStart
    case treeBalanceFinish
}

private struct WorkoutAvatarJoints {
    let head: CGPoint
    let leftShoulder: CGPoint
    let rightShoulder: CGPoint
    let leftElbow: CGPoint
    let rightElbow: CGPoint
    let leftHand: CGPoint
    let rightHand: CGPoint
    let leftHip: CGPoint
    let rightHip: CGPoint
    let leftKnee: CGPoint
    let rightKnee: CGPoint
    let leftAnkle: CGPoint
    let rightAnkle: CGPoint
}

/// Lightweight vector fallback for the approved faceless, Wii-like workout
/// figures. Raster or 3D character packs can be added later without removing this
/// renderer, which also guarantees that missing art never blocks a workout.
struct WorkoutAvatarFigure: View {
    let pose: WorkoutAvatarPose
    var style: WorkoutAvatarStyle = .nellNeutral
    var equipment: WorkoutAvatarEquipment = .none

    var body: some View {
        Canvas { context, size in
            let joints = joints(for: pose)
            let scale = min(size.width, size.height)
            let limbWidth = max(scale * 0.055, 4)
            let torsoWidth = max(scale * 0.13, 10)

            func point(_ value: CGPoint) -> CGPoint {
                CGPoint(x: value.x * size.width, y: value.y * size.height)
            }

            func line(_ start: CGPoint, _ end: CGPoint, colour: Color, width: CGFloat) {
                var path = Path()
                path.move(to: point(start))
                path.addLine(to: point(end))
                context.stroke(
                    path,
                    with: .color(colour),
                    style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                )
            }

            // Back limbs.
            line(joints.rightHip, joints.rightKnee, colour: style.skin, width: limbWidth)
            line(joints.rightKnee, joints.rightAnkle, colour: style.skin, width: limbWidth)
            line(joints.rightShoulder, joints.rightElbow, colour: style.skin, width: limbWidth)
            line(joints.rightElbow, joints.rightHand, colour: style.skin, width: limbWidth)

            // Shorts and torso.
            line(joints.leftHip, joints.rightHip, colour: style.bottoms, width: torsoWidth * 0.78)
            let shoulderCentre = midpoint(joints.leftShoulder, joints.rightShoulder)
            let hipCentre = midpoint(joints.leftHip, joints.rightHip)
            line(shoulderCentre, hipCentre, colour: style.top, width: torsoWidth)
            line(joints.leftShoulder, joints.rightShoulder, colour: style.top, width: torsoWidth * 0.72)

            // Front limbs.
            line(joints.leftHip, joints.leftKnee, colour: style.skin, width: limbWidth)
            line(joints.leftKnee, joints.leftAnkle, colour: style.skin, width: limbWidth)
            line(joints.leftShoulder, joints.leftElbow, colour: style.skin, width: limbWidth)
            line(joints.leftElbow, joints.leftHand, colour: style.skin, width: limbWidth)

            drawFoot(at: joints.leftAnkle, context: &context, size: size, colour: style.shoes)
            drawFoot(at: joints.rightAnkle, context: &context, size: size, colour: style.shoes)

            // Faceless head and restrained hair cap.
            let headPoint = point(joints.head)
            let headDiameter = max(scale * 0.13, 12)
            let headRect = CGRect(
                x: headPoint.x - headDiameter / 2,
                y: headPoint.y - headDiameter / 2,
                width: headDiameter,
                height: headDiameter
            )
            context.fill(Path(ellipseIn: headRect), with: .color(style.skin))
            let hairRect = CGRect(
                x: headRect.minX,
                y: headRect.minY,
                width: headRect.width,
                height: headRect.height * 0.46
            )
            context.fill(Path(ellipseIn: hairRect), with: .color(style.hair))

            drawEquipment(
                equipment,
                leftHand: joints.leftHand,
                rightHand: joints.rightHand,
                context: &context,
                size: size,
                colour: style.equipment
            )
        }
        .aspectRatio(0.72, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Faceless workout motion figure")
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }

    private func drawFoot(
        at ankle: CGPoint,
        context: inout GraphicsContext,
        size: CGSize,
        colour: Color
    ) {
        let origin = CGPoint(x: ankle.x * size.width, y: ankle.y * size.height)
        var path = Path()
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x + size.width * 0.045, y: origin.y))
        context.stroke(
            path,
            with: .color(colour),
            style: StrokeStyle(lineWidth: max(min(size.width, size.height) * 0.045, 4), lineCap: .round)
        )
    }

    private func drawEquipment(
        _ equipment: WorkoutAvatarEquipment,
        leftHand: CGPoint,
        rightHand: CGPoint,
        context: inout GraphicsContext,
        size: CGSize,
        colour: Color
    ) {
        switch equipment {
        case .none:
            return
        case .dumbbells:
            drawDumbbell(at: leftHand, context: &context, size: size, colour: colour)
            drawDumbbell(at: rightHand, context: &context, size: size, colour: colour)
        case .gobletWeight:
            let centre = midpoint(leftHand, rightHand)
            let point = CGPoint(x: centre.x * size.width, y: centre.y * size.height)
            let radius = max(min(size.width, size.height) * 0.052, 5)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color(colour)
            )
        }
    }

    private func drawDumbbell(
        at hand: CGPoint,
        context: inout GraphicsContext,
        size: CGSize,
        colour: Color
    ) {
        let centre = CGPoint(x: hand.x * size.width, y: hand.y * size.height)
        let width = max(size.width * 0.075, 8)
        let plate = max(min(size.width, size.height) * 0.028, 3)
        var path = Path()
        path.move(to: CGPoint(x: centre.x - width / 2, y: centre.y))
        path.addLine(to: CGPoint(x: centre.x + width / 2, y: centre.y))
        context.stroke(path, with: .color(colour), lineWidth: max(plate * 0.7, 2))
        context.fill(
            Path(ellipseIn: CGRect(x: centre.x - width / 2 - plate, y: centre.y - plate, width: plate * 2, height: plate * 2)),
            with: .color(colour)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: centre.x + width / 2 - plate, y: centre.y - plate, width: plate * 2, height: plate * 2)),
            with: .color(colour)
        )
    }

    private func joints(for pose: WorkoutAvatarPose) -> WorkoutAvatarJoints {
        switch pose {
        case .standing:
            return .init(
                head: .init(x: 0.50, y: 0.12),
                leftShoulder: .init(x: 0.42, y: 0.28), rightShoulder: .init(x: 0.58, y: 0.28),
                leftElbow: .init(x: 0.38, y: 0.44), rightElbow: .init(x: 0.62, y: 0.44),
                leftHand: .init(x: 0.36, y: 0.58), rightHand: .init(x: 0.64, y: 0.58),
                leftHip: .init(x: 0.45, y: 0.53), rightHip: .init(x: 0.55, y: 0.53),
                leftKnee: .init(x: 0.44, y: 0.72), rightKnee: .init(x: 0.56, y: 0.72),
                leftAnkle: .init(x: 0.42, y: 0.91), rightAnkle: .init(x: 0.58, y: 0.91)
            )
        case .gobletSquat:
            return .init(
                head: .init(x: 0.51, y: 0.20),
                leftShoulder: .init(x: 0.43, y: 0.34), rightShoulder: .init(x: 0.59, y: 0.34),
                leftElbow: .init(x: 0.42, y: 0.45), rightElbow: .init(x: 0.58, y: 0.45),
                leftHand: .init(x: 0.48, y: 0.48), rightHand: .init(x: 0.52, y: 0.48),
                leftHip: .init(x: 0.45, y: 0.57), rightHip: .init(x: 0.57, y: 0.57),
                leftKnee: .init(x: 0.31, y: 0.70), rightKnee: .init(x: 0.72, y: 0.70),
                leftAnkle: .init(x: 0.27, y: 0.88), rightAnkle: .init(x: 0.76, y: 0.88)
            )
        case .hipHinge:
            return .init(
                head: .init(x: 0.68, y: 0.27),
                leftShoulder: .init(x: 0.54, y: 0.36), rightShoulder: .init(x: 0.66, y: 0.39),
                leftElbow: .init(x: 0.56, y: 0.53), rightElbow: .init(x: 0.68, y: 0.55),
                leftHand: .init(x: 0.58, y: 0.68), rightHand: .init(x: 0.70, y: 0.69),
                leftHip: .init(x: 0.37, y: 0.55), rightHip: .init(x: 0.48, y: 0.56),
                leftKnee: .init(x: 0.34, y: 0.72), rightKnee: .init(x: 0.52, y: 0.72),
                leftAnkle: .init(x: 0.29, y: 0.91), rightAnkle: .init(x: 0.57, y: 0.91)
            )
        case .bentOverRow:
            return .init(
                head: .init(x: 0.68, y: 0.27),
                leftShoulder: .init(x: 0.54, y: 0.36), rightShoulder: .init(x: 0.66, y: 0.39),
                leftElbow: .init(x: 0.47, y: 0.48), rightElbow: .init(x: 0.58, y: 0.50),
                leftHand: .init(x: 0.43, y: 0.58), rightHand: .init(x: 0.54, y: 0.60),
                leftHip: .init(x: 0.37, y: 0.55), rightHip: .init(x: 0.48, y: 0.56),
                leftKnee: .init(x: 0.34, y: 0.72), rightKnee: .init(x: 0.52, y: 0.72),
                leftAnkle: .init(x: 0.29, y: 0.91), rightAnkle: .init(x: 0.57, y: 0.91)
            )
        case .overheadStart:
            return .init(
                head: .init(x: 0.50, y: 0.15),
                leftShoulder: .init(x: 0.42, y: 0.31), rightShoulder: .init(x: 0.58, y: 0.31),
                leftElbow: .init(x: 0.36, y: 0.36), rightElbow: .init(x: 0.64, y: 0.36),
                leftHand: .init(x: 0.38, y: 0.25), rightHand: .init(x: 0.62, y: 0.25),
                leftHip: .init(x: 0.45, y: 0.55), rightHip: .init(x: 0.55, y: 0.55),
                leftKnee: .init(x: 0.44, y: 0.73), rightKnee: .init(x: 0.56, y: 0.73),
                leftAnkle: .init(x: 0.42, y: 0.91), rightAnkle: .init(x: 0.58, y: 0.91)
            )
        case .overheadFinish:
            return .init(
                head: .init(x: 0.50, y: 0.20),
                leftShoulder: .init(x: 0.42, y: 0.35), rightShoulder: .init(x: 0.58, y: 0.35),
                leftElbow: .init(x: 0.40, y: 0.20), rightElbow: .init(x: 0.60, y: 0.20),
                leftHand: .init(x: 0.40, y: 0.07), rightHand: .init(x: 0.60, y: 0.07),
                leftHip: .init(x: 0.45, y: 0.58), rightHip: .init(x: 0.55, y: 0.58),
                leftKnee: .init(x: 0.44, y: 0.75), rightKnee: .init(x: 0.56, y: 0.75),
                leftAnkle: .init(x: 0.42, y: 0.92), rightAnkle: .init(x: 0.58, y: 0.92)
            )
        case .splitSquat:
            return .init(
                head: .init(x: 0.48, y: 0.14),
                leftShoulder: .init(x: 0.40, y: 0.30), rightShoulder: .init(x: 0.56, y: 0.30),
                leftElbow: .init(x: 0.34, y: 0.45), rightElbow: .init(x: 0.62, y: 0.45),
                leftHand: .init(x: 0.32, y: 0.58), rightHand: .init(x: 0.64, y: 0.58),
                leftHip: .init(x: 0.43, y: 0.54), rightHip: .init(x: 0.54, y: 0.54),
                leftKnee: .init(x: 0.31, y: 0.71), rightKnee: .init(x: 0.70, y: 0.74),
                leftAnkle: .init(x: 0.24, y: 0.90), rightAnkle: .init(x: 0.82, y: 0.90)
            )
        case .plank:
            return .init(
                head: .init(x: 0.76, y: 0.34),
                leftShoulder: .init(x: 0.65, y: 0.42), rightShoulder: .init(x: 0.68, y: 0.48),
                leftElbow: .init(x: 0.70, y: 0.61), rightElbow: .init(x: 0.76, y: 0.64),
                leftHand: .init(x: 0.72, y: 0.78), rightHand: .init(x: 0.80, y: 0.79),
                leftHip: .init(x: 0.43, y: 0.49), rightHip: .init(x: 0.46, y: 0.55),
                leftKnee: .init(x: 0.25, y: 0.60), rightKnee: .init(x: 0.28, y: 0.66),
                leftAnkle: .init(x: 0.09, y: 0.70), rightAnkle: .init(x: 0.12, y: 0.76)
            )
        case .plankRow:
            return .init(
                head: .init(x: 0.75, y: 0.34),
                leftShoulder: .init(x: 0.64, y: 0.42), rightShoulder: .init(x: 0.67, y: 0.48),
                leftElbow: .init(x: 0.54, y: 0.44), rightElbow: .init(x: 0.74, y: 0.64),
                leftHand: .init(x: 0.48, y: 0.53), rightHand: .init(x: 0.78, y: 0.79),
                leftHip: .init(x: 0.43, y: 0.49), rightHip: .init(x: 0.46, y: 0.55),
                leftKnee: .init(x: 0.25, y: 0.60), rightKnee: .init(x: 0.28, y: 0.66),
                leftAnkle: .init(x: 0.09, y: 0.70), rightAnkle: .init(x: 0.12, y: 0.76)
            )
        case .sideStretchStart:
            return .init(
                head: .init(x: 0.50, y: 0.14),
                leftShoulder: .init(x: 0.42, y: 0.30), rightShoulder: .init(x: 0.58, y: 0.30),
                leftElbow: .init(x: 0.33, y: 0.36), rightElbow: .init(x: 0.61, y: 0.16),
                leftHand: .init(x: 0.27, y: 0.50), rightHand: .init(x: 0.61, y: 0.05),
                leftHip: .init(x: 0.45, y: 0.55), rightHip: .init(x: 0.55, y: 0.55),
                leftKnee: .init(x: 0.44, y: 0.73), rightKnee: .init(x: 0.56, y: 0.73),
                leftAnkle: .init(x: 0.42, y: 0.91), rightAnkle: .init(x: 0.58, y: 0.91)
            )
        case .sideStretchFinish:
            return .init(
                head: .init(x: 0.62, y: 0.20),
                leftShoulder: .init(x: 0.50, y: 0.34), rightShoulder: .init(x: 0.64, y: 0.38),
                leftElbow: .init(x: 0.39, y: 0.44), rightElbow: .init(x: 0.53, y: 0.17),
                leftHand: .init(x: 0.34, y: 0.58), rightHand: .init(x: 0.43, y: 0.08),
                leftHip: .init(x: 0.43, y: 0.57), rightHip: .init(x: 0.54, y: 0.59),
                leftKnee: .init(x: 0.42, y: 0.75), rightKnee: .init(x: 0.55, y: 0.76),
                leftAnkle: .init(x: 0.40, y: 0.92), rightAnkle: .init(x: 0.57, y: 0.92)
            )
        case .treeBalanceStart:
            return joints(for: .standing)
        case .treeBalanceFinish:
            return .init(
                head: .init(x: 0.50, y: 0.13),
                leftShoulder: .init(x: 0.42, y: 0.29), rightShoulder: .init(x: 0.58, y: 0.29),
                leftElbow: .init(x: 0.31, y: 0.33), rightElbow: .init(x: 0.69, y: 0.33),
                leftHand: .init(x: 0.20, y: 0.35), rightHand: .init(x: 0.80, y: 0.35),
                leftHip: .init(x: 0.45, y: 0.54), rightHip: .init(x: 0.55, y: 0.54),
                leftKnee: .init(x: 0.31, y: 0.64), rightKnee: .init(x: 0.56, y: 0.73),
                leftAnkle: .init(x: 0.47, y: 0.65), rightAnkle: .init(x: 0.58, y: 0.91)
            )
        }
    }
}
