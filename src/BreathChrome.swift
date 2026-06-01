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
            let progressX = width * CGFloat(snapshot.cycleProgress)

            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: midY))

            for step in 0...80 {
                let x = width * CGFloat(step) / 80
                let angle = Double(x / width) * 2 * Double.pi
                let y = midY - CGFloat(sin(angle)) * amplitude
                wave.addLine(to: CGPoint(x: x, y: y))
            }

            context.stroke(
                wave,
                with: .color(.white.opacity(0.18)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )

            var active = Path()
            active.move(to: CGPoint(x: 0, y: midY))

            for step in 0...80 {
                let x = min(progressX, width * CGFloat(step) / 80)
                let angle = Double(x / width) * 2 * Double.pi
                let y = midY - CGFloat(sin(angle)) * amplitude
                active.addLine(to: CGPoint(x: x, y: y))

                if x >= progressX {
                    break
                }
            }

            context.stroke(
                active,
                with: .color(color.opacity(0.88)),
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
            )

            context.fill(
                Path(ellipseIn: CGRect(x: progressX - 3, y: midY - 3 - CGFloat(snapshot.sine) * amplitude, width: 6, height: 6)),
                with: .color(.white.opacity(0.86))
            )
        }
    }
}
