import Foundation
import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(MeditationPersistenceKey.panelRawValue) private var panelRawValue = MeditationPanel.breathingHorizon.rawValue
    @AppStorage(MeditationPersistenceKey.lastAnimationModeRawValue) private var lastAnimationModeRawValue = MeditationAnimationMode.breathingHorizon.rawValue
    @AppStorage(MeditationPersistenceKey.breathsPerMinute) private var breathsPerMinute = MeditationSettings.defaultBreathsPerMinute
    @AppStorage(MeditationPersistenceKey.hapticIntensity) private var hapticIntensity = MeditationSettings.defaultHapticIntensity
    @AppStorage(MeditationPersistenceKey.hapticFrequency) private var hapticFrequency = MeditationSettings.defaultHapticFrequency

    @State private var startedAt = Date()
    @State private var chromeVisible = true
    @State private var chromeFadeToken = 0
    @StateObject private var haptics = BreathHapticCoordinator()
    @StateObject private var diagnostics = FrameDiagnosticsSampler()

    private var panel: MeditationPanel {
        MeditationPanel(rawValue: panelRawValue) ?? .breathingHorizon
    }

    private var currentMode: MeditationAnimationMode {
        MeditationAnimationMode(rawValue: lastAnimationModeRawValue) ?? .breathingHorizon
    }

    private var timeline: BreathingTimeline {
        settings.timeline
    }

    private var settings: MeditationSettings {
        MeditationSettings(
            breathsPerMinute: clamped(breathsPerMinute, to: MeditationSettings.breathsPerMinuteRange),
            hapticIntensity: clamped(hapticIntensity, to: MeditationSettings.hapticIntensityRange),
            hapticFrequency: clamped(hapticFrequency, to: MeditationSettings.hapticFrequencyRange)
        )
    }

    private var activeAnimationMode: MeditationAnimationMode {
        panel.animationMode ?? currentMode
    }

    private var hapticsLoopID: HapticsLoopID {
        HapticsLoopID(startedAt: startedAt, settings: settings)
    }

    var body: some View {
        let activeMode = activeAnimationMode

        ZStack {
            MeditationScene(
                mode: activeMode,
                startedAt: startedAt,
                timeline: timeline,
                reduceMotion: reduceMotion,
                diagnostics: diagnostics
            )
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(swipeGesture)
                .simultaneousGesture(TapGesture().onEnded { revealChromeTemporarily() })

            VStack {
                DiagnosticsOverlay(snapshot: diagnostics.snapshot)
                    .padding(.top, 14)
                    .padding(.leading, 14)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            VStack {
                Spacer()

                if panel == .configuration {
                    ConfigurationPanel(
                        breathsPerMinute: $breathsPerMinute,
                        hapticIntensity: $hapticIntensity,
                        hapticFrequency: $hapticFrequency
                    )
                        .padding(.bottom, 16)
                } else {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                        BreathCaption(
                            mode: activeMode,
                            snapshot: timeline.snapshot(at: context.date, startedAt: startedAt)
                        )
                    }
                }

                PanelSwitcher(selection: panel) { selectedPanel in
                    setPanel(selectedPanel)
                }
            }
            .opacity(panel == .configuration || chromeVisible ? 1 : 0)
            .allowsHitTesting(panel == .configuration || chromeVisible)
            .accessibilityHidden(panel != .configuration && !chromeVisible)
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .onAppear {
            if let launchOverride = MeditationPanel.launchOverride() {
                setPanel(launchOverride, reveal: false)
            }

            startedAt = Date().addingTimeInterval(-BreathingTimeline.initialElapsedOffset)
            updateMeditationActive(true)
            haptics.startLoopingPattern(for: timeline, elapsed: BreathingTimeline.initialElapsedOffset)
            revealChromeTemporarily()
        }
        .task(id: hapticsLoopID) {
            await runHapticsLoop(startedAt: startedAt, settings: settings)
        }
        .onChange(of: settings) { _, newSettings in
            let elapsed = Date().timeIntervalSince(startedAt)
            haptics.startLoopingPattern(for: newSettings.timeline, elapsed: elapsed)
        }
        .task(id: chromeFadeToken) {
            guard panel != .configuration else {
                return
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)

            guard !Task.isCancelled, panel != .configuration else {
                return
            }

            withAnimation(.easeOut(duration: 0.45)) {
                chromeVisible = false
            }
        }
        .onChange(of: panel) { _, newPanel in
            revealChromeTemporarily()
        }
        .onDisappear {
            updateMeditationActive(false)
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

                guard let nextPanel = horizontal < 0 ? panel.next : panel.previous else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.38)) {
                    setPanel(nextPanel)
                }
            }
    }

    private func runHapticsLoop(startedAt: Date, settings: MeditationSettings) async {
        let timeline = settings.timeline

        while !Task.isCancelled {
            let date = Date()
            haptics.update(with: timeline.snapshot(at: date, startedAt: startedAt), at: date)
            try? await Task.sleep(nanoseconds: 24_000_000)
        }

        haptics.stop()
    }

    private func setPanel(_ newPanel: MeditationPanel, reveal: Bool = true) {
        panelRawValue = newPanel.rawValue

        if let animationMode = newPanel.animationMode {
            lastAnimationModeRawValue = animationMode.rawValue
        }

        if reveal {
            revealChromeTemporarily()
        }
    }

    private func revealChromeTemporarily() {
        withAnimation(.easeOut(duration: 0.22)) {
            chromeVisible = true
        }
        chromeFadeToken += 1
    }

    private func updateMeditationActive(_ active: Bool) {
        PlatformSessionControls.setMeditationActive(active)

        if !active {
            haptics.stop()
        }
    }

    private func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct HapticsLoopID: Equatable {
    let startedAt: Date
    let settings: MeditationSettings
}

private struct MeditationScene: View {
    let mode: MeditationAnimationMode
    let startedAt: Date
    let timeline: BreathingTimeline
    let reduceMotion: Bool
    @ObservedObject var diagnostics: FrameDiagnosticsSampler

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
            let snapshot = timeline.snapshot(at: context.date, startedAt: startedAt)
            let time = context.date.timeIntervalSinceReferenceDate

            let _ = Task { @MainActor in
                diagnostics.recordFrame(at: context.date)
            }

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

private struct DiagnosticsOverlay: View {
    let snapshot: FrameDiagnosticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(format: "FPS %.1f / %.0f", snapshot.framesPerSecond, snapshot.targetFramesPerSecond))
            Text(String(format: "Frame %.1f ms", snapshot.frameMilliseconds))

            if let cpuUsagePercent = snapshot.cpuUsagePercent {
                Text(String(format: "CPU %.0f%%", cpuUsagePercent))
            } else {
                Text("CPU n/a")
            }

            Text("Thermal \(snapshot.thermalState.diagnosticTitle)")
            Text(snapshot.isLowPowerModeEnabled ? "Low power on" : "Low power off")
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.76))
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension ProcessInfo.ThermalState {
    var diagnosticTitle: String {
        switch self {
        case .nominal:
            "nominal"
        case .fair:
            "fair"
        case .serious:
            "serious"
        case .critical:
            "critical"
        @unknown default:
            "unknown"
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

private struct ConfigurationPanel: View {
    @Binding var breathsPerMinute: Double
    @Binding var hapticIntensity: Double
    @Binding var hapticFrequency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Label("Configuration", systemImage: "slider.horizontal.3")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
            }

            ConfigurationSlider(
                title: "Breathing speed",
                valueText: String(format: "%.1f bpm", breathsPerMinute),
                systemImage: "wind",
                value: $breathsPerMinute,
                range: MeditationSettings.breathsPerMinuteRange,
                step: 0.5,
                accent: Color(red: 1.0, green: 0.74, blue: 0.49)
            )

            ConfigurationSlider(
                title: "Haptics intensity",
                valueText: "\(Int((hapticIntensity * 100).rounded()))%",
                systemImage: "waveform.path",
                value: $hapticIntensity,
                range: MeditationSettings.hapticIntensityRange,
                step: 0.05,
                accent: Color(red: 0.72, green: 0.56, blue: 1.0)
            )

            ConfigurationSlider(
                title: "Haptics frequency",
                valueText: "\(Int((hapticFrequency * 100).rounded()))%",
                systemImage: "dot.radiowaves.left.and.right",
                value: $hapticFrequency,
                range: MeditationSettings.hapticFrequencyRange,
                step: 0.05,
                accent: Color(red: 0.56, green: 0.86, blue: 1.0)
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(maxWidth: 380, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 18)
        .accessibilityElement(children: .contain)
    }
}

private struct ConfigurationSlider: View {
    let title: String
    let valueText: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24)

                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                Spacer()

                Text(valueText)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.72))
            }

            Slider(value: $value, in: range, step: step)
                .tint(accent)
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }
}


private struct BreathCaption: View {
    let mode: MeditationAnimationMode
    let snapshot: BreathingSnapshot

    var body: some View {
        VStack {
            BreathWave(snapshot: snapshot, color: mode.accent)
                .frame(width: 156, height: 28)
                .accessibilityHidden(true)
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

private struct PanelSwitcher: View {
    let selection: MeditationPanel
    let onSelect: (MeditationPanel) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MeditationPanel.allCases) { panel in
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        onSelect(panel)
                    }
                } label: {
                    HStack(spacing: 7) {
                        panelIcon(panel)
                            .frame(width: 14, height: 14)
                            .shadow(color: panel.accent.opacity(panel == selection ? 0.9 : 0.0), radius: 7)

                        if panel == selection {
                            Text(panel.shortTitle)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.white.opacity(panel == selection ? 0.92 : 0.56))
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.horizontal, panel == selection ? 12 : 9)
                    .background(
                        Capsule()
                            .fill(.white.opacity(panel == selection ? 0.14 : 0.07))
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(panel == selection ? 0.18 : 0.08), lineWidth: 1)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Panel: \(panel.title)")
                .accessibilityValue(panel == selection ? "Selected" : "")
                .accessibilityHint(panel == selection ? "Current panel" : "Switches the meditation panel")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.16), in: Capsule())
    }

    @ViewBuilder
    private func panelIcon(_ panel: MeditationPanel) -> some View {
        switch panel {
        case .configuration:
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(panel.accent)
        case .breathingHorizon, .silkRibbon, .inkBloom:
            Circle()
                .fill(panel.accent)
                .frame(width: 7, height: 7)
        }
    }
}
