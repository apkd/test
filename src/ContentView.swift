import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var startedAt = Date()
    @State private var mode = MeditationAnimationMode.defaultMode
    @StateObject private var haptics = BreathHapticCoordinator()

    private let timeline = BreathingTimeline()
    private var hapticsLoopID: HapticsLoopID {
        HapticsLoopID(startedAt: startedAt, isSceneActive: scenePhase == .active)
    }

    var body: some View {
        ZStack {
            MeditationScene(mode: mode, startedAt: startedAt, timeline: timeline, reduceMotion: reduceMotion)

            VStack {
                topLabel

                Spacer()

                TimelineView(.animation) { context in
                    BreathCaption(
                        mode: mode,
                        snapshot: timeline.snapshot(at: context.date, startedAt: startedAt),
                        reduceMotion: reduceMotion
                    )
                }

                ModeSwitcher(selection: $mode)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(swipeGesture)
        .onAppear {
            startedAt = Date().addingTimeInterval(-BreathingTimeline.initialElapsedOffset)
            updateMeditationActive(scenePhase == .active)
        }
        .task(id: hapticsLoopID) {
            guard scenePhase == .active else {
                haptics.stop()
                return
            }

            await runHapticsLoop(startedAt: startedAt)
        }
        .onChange(of: scenePhase) { _, newPhase in
            updateMeditationActive(newPhase == .active)
        }
        .onDisappear {
            updateMeditationActive(false)
        }
    }

    private var topLabel: some View {
        HStack {
            Label("Meditation", systemImage: "sparkles")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.68))

            Spacer()
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 38)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical), abs(horizontal) > 44 else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.38)) {
                    mode = horizontal < 0 ? mode.next : mode.previous
                }
            }
    }

    private func runHapticsLoop(startedAt: Date) async {
        while !Task.isCancelled {
            let date = Date()
            haptics.update(with: timeline.snapshot(at: date, startedAt: startedAt), at: date)
            try? await Task.sleep(nanoseconds: 24_000_000)
        }

        haptics.stop()
    }

    private func updateMeditationActive(_ active: Bool) {
        PlatformSessionControls.setMeditationActive(active)

        if !active {
            haptics.stop()
        }
    }
}

private struct HapticsLoopID: Equatable {
    let startedAt: Date
    let isSceneActive: Bool
}

private struct MeditationScene: View {
    let mode: MeditationAnimationMode
    let startedAt: Date
    let timeline: BreathingTimeline
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let snapshot = timeline.snapshot(at: context.date, startedAt: startedAt)
            let time = context.date.timeIntervalSinceReferenceDate

            ZStack {
                AmbientBackground(mode: mode, snapshot: snapshot, reduceMotion: reduceMotion)

                MeditationArtwork(mode: mode, snapshot: snapshot, time: time, reduceMotion: reduceMotion)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .id(mode)
            }
            .animation(.easeInOut(duration: 0.5), value: mode)
        }
    }
}

private struct AmbientBackground: View {
    let mode: MeditationAnimationMode
    let snapshot: BreathingSnapshot
    let reduceMotion: Bool

    var body: some View {
        let breathScale = reduceMotion ? 0.04 : 0.15

        ZStack {
            LinearGradient(
                colors: baseColors,
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

    private var baseColors: [Color] {
        switch mode {
        case .silkRibbon:
            [
                Color(red: 0.035, green: 0.045, blue: 0.09),
                Color(red: 0.08, green: 0.13, blue: 0.24),
                Color(red: 0.02, green: 0.025, blue: 0.055),
            ]
        case .breathingHorizon:
            [
                Color(red: 0.08, green: 0.10, blue: 0.18),
                Color(red: 0.20, green: 0.20, blue: 0.34),
                Color(red: 0.04, green: 0.07, blue: 0.12),
            ]
        case .inkBloom:
            [
                Color(red: 0.025, green: 0.02, blue: 0.06),
                Color(red: 0.09, green: 0.055, blue: 0.16),
                Color(red: 0.015, green: 0.015, blue: 0.04),
            ]
        }
    }
}

private struct MeditationArtwork: View {
    let mode: MeditationAnimationMode
    let snapshot: BreathingSnapshot
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, size in
            switch mode {
            case .silkRibbon:
                MeditationRenderer.drawSilkRibbon(in: &context, size: size, snapshot: snapshot, time: time, reduceMotion: reduceMotion)
            case .breathingHorizon:
                MeditationRenderer.drawBreathingHorizon(in: &context, size: size, snapshot: snapshot, time: time, reduceMotion: reduceMotion)
            case .inkBloom:
                MeditationRenderer.drawInkBloom(in: &context, size: size, snapshot: snapshot, time: time, reduceMotion: reduceMotion)
            }
        }
        .drawingGroup()
    }
}


private struct BreathCaption: View {
    let mode: MeditationAnimationMode
    let snapshot: BreathingSnapshot
    let reduceMotion: Bool

    var body: some View {
        let breathOpacity = 0.74 + (reduceMotion ? 0.06 : 0.16) * snapshot.breathAmount
        let inhaleOpacity = BreathingTimeline.smoothstep((snapshot.sine + 0.16) / 0.32)

        VStack(spacing: 10) {
            ZStack {
                phaseText("Breathe out", opacity: (1 - inhaleOpacity) * breathOpacity)
                phaseText("Breathe in", opacity: inhaleOpacity * breathOpacity)
            }
            .frame(height: 44)
            .accessibilityLabel(snapshot.phase.title)

            Text(mode.instruction)
                .font(.system(.callout, design: .rounded, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.70))
                .frame(maxWidth: 330)

            BreathWave(snapshot: snapshot, color: mode.accent)
                .frame(width: 126, height: 20)
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshot.phase.title). \(mode.title). \(mode.instruction)")
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.bottom, 16)
    }

    private func phaseText(_ text: String, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 36, weight: .light, design: .rounded))
            .foregroundStyle(.white.opacity(opacity))
            .shadow(color: mode.accent.opacity(0.22), radius: 16, y: 7)
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

private struct ModeSwitcher: View {
    @Binding var selection: MeditationAnimationMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MeditationAnimationMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        selection = mode
                    }
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(mode.accent)
                            .frame(width: 7, height: 7)
                            .shadow(color: mode.accent.opacity(mode == selection ? 0.9 : 0.0), radius: 7)

                        if mode == selection {
                            Text(mode.shortTitle)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.white.opacity(mode == selection ? 0.92 : 0.56))
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.horizontal, mode == selection ? 12 : 9)
                    .background(
                        Capsule()
                            .fill(.white.opacity(mode == selection ? 0.14 : 0.07))
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(mode == selection ? 0.18 : 0.08), lineWidth: 1)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Animation mode: \(mode.title)")
                .accessibilityValue(mode == selection ? "Selected" : "")
                .accessibilityHint(mode == selection ? "Current animation mode" : "Switches the breathing animation")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.16), in: Capsule())
    }
}
