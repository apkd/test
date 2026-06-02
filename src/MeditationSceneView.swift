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
                let time = snapshot.elapsed
                let width = max(1, geometry.size.width)
                let baseMode = transition?.fromMode ?? mode
                let parallax = min(width * 0.30, 136)

                ZStack {
                    MeditationVisualLayer(
                        mode: baseMode,
                        snapshot: snapshot,
                        time: time,
                        reduceMotion: reduceMotion
                    )

                    if let transition {
                        MeditationVisualLayer(
                            mode: transition.toMode,
                            snapshot: snapshot,
                            time: time,
                            reduceMotion: reduceMotion
                        )
                        .offset(x: -transition.direction.sign * (1 - transition.progress) * parallax)
                        .mask {
                            SceneRevealMask(
                                direction: transition.direction,
                                progress: transition.progress
                            )
                        }
                    }
                }
                .clipped()
            }
        }
    }
}

private struct SceneRevealMask: View {
    let direction: PanelSwipeDirection
    let progress: CGFloat

    var body: some View {
        LinearGradient(
            stops: stops(progress: max(0, min(1, progress))),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func stops(progress: CGFloat) -> [Gradient.Stop] {
        let fadeWidth: CGFloat = 0.24

        switch direction {
        case .next:
            let edge = 1 - progress
            let fadeStart = max(0, edge - fadeWidth)
            return [
                Gradient.Stop(color: .clear, location: 0),
                Gradient.Stop(color: .clear, location: fadeStart),
                Gradient.Stop(color: .white, location: edge),
                Gradient.Stop(color: .white, location: 1),
            ]
        case .previous:
            let edge = progress
            let fadeEnd = min(1, edge + fadeWidth)
            return [
                Gradient.Stop(color: .white, location: 0),
                Gradient.Stop(color: .white, location: edge),
                Gradient.Stop(color: .clear, location: fadeEnd),
                Gradient.Stop(color: .clear, location: 1),
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
            let warmth = Double(BreathingTimeline.smoothstep(Double(breathAmount))) * 0.42
            return [
                Self.color(red: 0.018, green: 0.026, blue: 0.055, warmRed: 0.055, warmGreen: 0.032, warmBlue: 0.060, amount: warmth),
                Self.color(red: 0.030, green: 0.070, blue: 0.130, warmRed: 0.115, warmGreen: 0.075, warmBlue: 0.130, amount: warmth),
                Self.color(red: 0.006, green: 0.010, blue: 0.026, warmRed: 0.030, warmGreen: 0.018, warmBlue: 0.034, amount: warmth),
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
