import SwiftUI

enum PanelSwipeDirection: Equatable {
    case previous
    case next

    init?(translation: CGFloat) {
        if translation < 0 {
            self = .next
        } else if translation > 0 {
            self = .previous
        } else {
            return nil
        }
    }

    var sign: CGFloat {
        switch self {
        case .previous:
            1
        case .next:
            -1
        }
    }

    fileprivate var incomingFadeEdge: SceneFadeEdge {
        switch self {
        case .previous:
            .trailing
        case .next:
            .leading
        }
    }

    fileprivate var outgoingFadeEdge: SceneFadeEdge {
        switch self {
        case .previous:
            .leading
        case .next:
            .trailing
        }
    }
}

struct PanelTransition: Equatable {
    let fromPanel: MeditationPanel
    let toPanel: MeditationPanel
    let direction: PanelSwipeDirection
    let progress: CGFloat

    func withProgress(_ progress: CGFloat) -> PanelTransition {
        PanelTransition(
            fromPanel: fromPanel,
            toPanel: toPanel,
            direction: direction,
            progress: progress
        )
    }
}

struct MeditationSceneTransition: Equatable {
    let fromMode: MeditationAnimationMode
    let toMode: MeditationAnimationMode
    let direction: PanelSwipeDirection
    let progress: CGFloat
}

struct MeditationScene: View {
    let mode: MeditationAnimationMode
    let transition: MeditationSceneTransition?
    let startedAt: Date
    let timeline: BreathingTimeline
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                let snapshot = timeline.snapshot(at: context.date, startedAt: startedAt)
                let time = context.date.timeIntervalSinceReferenceDate
                let width = max(1, geometry.size.width)
                let progress = transition?.progress ?? 0
                let sign = transition?.direction.sign ?? 0
                let baseMode = transition?.fromMode ?? mode
                let parallax = min(width * 0.075, 34)

                ZStack {
                    MeditationVisualLayer(
                        mode: baseMode,
                        snapshot: snapshot,
                        time: time,
                        reduceMotion: reduceMotion
                    )
                    .offset(x: sign * progress * parallax)
                    .opacity(1 - Double(progress))
                    .mask {
                        SceneEdgeFadeMask(
                            edge: transition?.direction.outgoingFadeEdge,
                            strength: transition == nil ? 0 : progress * 0.42
                        )
                    }

                    if let transition {
                        MeditationVisualLayer(
                            mode: transition.toMode,
                            snapshot: snapshot,
                            time: time,
                            reduceMotion: reduceMotion
                        )
                        .offset(x: -transition.direction.sign * (1 - transition.progress) * parallax)
                        .opacity(Double(transition.progress))
                        .mask {
                            SceneEdgeFadeMask(
                                edge: transition.direction.incomingFadeEdge,
                                strength: (1 - transition.progress) * 0.56
                            )
                        }
                    }
                }
                .clipped()
            }
        }
    }
}

private enum SceneFadeEdge: Equatable {
    case leading
    case trailing
}

private struct SceneEdgeFadeMask: View {
    let edge: SceneFadeEdge?
    let strength: CGFloat

    var body: some View {
        if let edge, strength > 0.001 {
            LinearGradient(
                stops: stops(edge: edge, strength: max(0.06, min(0.62, strength))),
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Color.white
        }
    }

    private func stops(edge: SceneFadeEdge, strength: CGFloat) -> [Gradient.Stop] {
        switch edge {
        case .leading:
            [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: strength * 0.22),
                .init(color: .white, location: strength),
                .init(color: .white, location: 1),
            ]
        case .trailing:
            [
                .init(color: .white, location: 0),
                .init(color: .white, location: 1 - strength),
                .init(color: .clear, location: 1 - strength * 0.22),
                .init(color: .clear, location: 1),
            ]
        }
    }
}

private struct MeditationVisualLayer: View {
    let mode: MeditationAnimationMode
    let snapshot: BreathingSnapshot
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            AmbientBackground(mode: mode, snapshot: snapshot, reduceMotion: reduceMotion)

            MeditationArtwork(mode: mode, snapshot: snapshot, time: time, reduceMotion: reduceMotion)
        }
    }
}

private struct AmbientBackground: View {
    let mode: MeditationAnimationMode
    let snapshot: BreathingSnapshot
    let reduceMotion: Bool

    var body: some View {
        let breathScale = reduceMotion ? 0.04 : 0.15
        let breathAmount = CGFloat(snapshot.breathAmount)

        ZStack {
            LinearGradient(
                colors: baseColors(breathAmount: breathAmount),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    mode.accent.opacity(0.34 + 0.16 * snapshot.breathAmount),
                    .clear,
                ],
                center: .center,
                startRadius: 24,
                endRadius: 520
            )
            .scaleEffect(1.04 + breathScale * snapshot.breathAmount)

            Color.black.opacity(0.18)
        }
    }

    private func baseColors(breathAmount: CGFloat) -> [Color] {
        switch mode {
        case .silkRibbon:
            let warmth = Double(BreathingTimeline.smoothstep(Double(breathAmount))) * 0.58
            return [
                Self.color(red: 0.035, green: 0.045, blue: 0.09, warmRed: 0.11, warmGreen: 0.060, warmBlue: 0.085, amount: warmth),
                Self.color(red: 0.08, green: 0.13, blue: 0.24, warmRed: 0.24, warmGreen: 0.145, warmBlue: 0.21, amount: warmth),
                Self.color(red: 0.02, green: 0.025, blue: 0.055, warmRed: 0.075, warmGreen: 0.040, warmBlue: 0.065, amount: warmth),
            ]
        case .breathingHorizon:
            return [
                Color(red: 0.08, green: 0.10, blue: 0.18),
                Color(red: 0.20, green: 0.20, blue: 0.34),
                Color(red: 0.04, green: 0.07, blue: 0.12),
            ]
        case .inkBloom:
            return [
                Color(red: 0.025, green: 0.02, blue: 0.06),
                Color(red: 0.09, green: 0.055, blue: 0.16),
                Color(red: 0.015, green: 0.015, blue: 0.04),
            ]
        case .softGlow:
            return [
                Color(red: 0.010, green: 0.014, blue: 0.030),
                Color(red: 0.030, green: 0.042, blue: 0.080),
                Color(red: 0.006, green: 0.009, blue: 0.022),
            ]
        }
    }

    private static func color(
        red: Double,
        green: Double,
        blue: Double,
        warmRed: Double,
        warmGreen: Double,
        warmBlue: Double,
        amount: Double
    ) -> Color {
        Color(
            red: red + (warmRed - red) * amount,
            green: green + (warmGreen - green) * amount,
            blue: blue + (warmBlue - blue) * amount
        )
    }
}

private struct MeditationArtwork: View {
    let mode: MeditationAnimationMode
    let snapshot: BreathingSnapshot
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            switch mode {
            case .silkRibbon:
                MeditationRenderer.drawSilkRibbon(in: &context, size: size, snapshot: snapshot, time: time, reduceMotion: reduceMotion)
            case .breathingHorizon:
                MeditationRenderer.drawBreathingHorizon(in: &context, size: size, snapshot: snapshot, time: time, reduceMotion: reduceMotion)
            case .inkBloom:
                MeditationRenderer.drawInkBloom(in: &context, size: size, snapshot: snapshot, time: time, reduceMotion: reduceMotion)
            case .softGlow:
                MeditationRenderer.drawSoftGlow(in: &context, size: size, snapshot: snapshot, time: time, reduceMotion: reduceMotion)
            }
        }
    }
}
