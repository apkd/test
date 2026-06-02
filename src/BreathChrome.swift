import SwiftUI

struct BreathCaption: View {
    let mode: MeditationAnimationMode
    let snapshot: BreathingSnapshot

    var body: some View {
        VStack {
            BreathWave(snapshot: snapshot, color: mode.accent)
                .frame(width: 156, height: 28)
                .accessibilityHidden(true)

            Text(snapshot.phase.title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshot.phase.title). Breath progress")
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.bottom, 16)
    }
}

private struct BreathWave: View {
    let snapshot: BreathingSnapshot
    let color: Color

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let width = size.width
            let amplitude = size.height * 0.36
            let progress = min(1, max(0, CGFloat(snapshot.cycleProgress)))
            let progressX = width * progress

            func waveY(at progress: CGFloat) -> CGFloat {
                let angle = Double(progress) * 2 * Double.pi - Double.pi / 2
                return midY - CGFloat(sin(angle)) * amplitude
            }

            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: waveY(at: 0)))

            for step in 1...80 {
                let sample = CGFloat(step) / 80
                wave.addLine(to: CGPoint(x: width * sample, y: waveY(at: sample)))
            }

            context.stroke(
                wave,
                with: .color(.white.opacity(0.18)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )

            var active = Path()
            active.move(to: CGPoint(x: 0, y: waveY(at: 0)))

            if progress > 0 {
                let activeSteps = max(1, Int(ceil(progress * 80)))
                for step in 1...activeSteps {
                    let sample = min(progress, CGFloat(step) / 80)
                    active.addLine(to: CGPoint(x: width * sample, y: waveY(at: sample)))
                }
            }

            context.stroke(
                active,
                with: .color(color.opacity(0.88)),
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
            )

            let dotY = waveY(at: progress)
            context.fill(
                Path(ellipseIn: CGRect(x: progressX - 3, y: dotY - 3, width: 6, height: 6)),
                with: .color(.white.opacity(0.86))
            )
        }
    }
}
