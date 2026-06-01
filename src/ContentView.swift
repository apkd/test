import Foundation
import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(MeditationPersistenceKey.panelRawValue) private var panelRawValue = MeditationPanel.breathingHorizon.rawValue
    @AppStorage(MeditationPersistenceKey.lastAnimationModeRawValue) private var lastAnimationModeRawValue = MeditationAnimationMode.breathingHorizon.rawValue
    @AppStorage(MeditationPersistenceKey.breathsPerMinute) private var breathsPerMinute = MeditationSettings.defaultBreathsPerMinute
    @AppStorage(MeditationPersistenceKey.hapticIntensity) private var hapticIntensity = MeditationSettings.defaultHapticIntensity
    @AppStorage(MeditationPersistenceKey.hapticFrequency) private var hapticFrequency = MeditationSettings.defaultHapticFrequency
    @AppStorage(MeditationPersistenceKey.hapticCurveTiming) private var hapticCurveTiming = MeditationSettings.defaultHapticCurveTiming

    @State private var startedAt = Date()
    @State private var chromeVisible = true
    @State private var chromeFadeToken = 0
    @State private var settlingPanelTransition: PanelTransition?
    @State private var panelTransitionToken = 0
    @State private var configurationVisible = false
    @GestureState private var liveSwipeTranslation: CGFloat = 0
    @StateObject private var haptics = BreathHapticCoordinator()
    @StateObject private var diagnostics = FrameDiagnosticsSampler()

    private var panel: MeditationPanel {
        let resolvedPanel = MeditationPanel(rawValue: panelRawValue) ?? .breathingHorizon
        return resolvedPanel == .configuration ? MeditationPanel.panel(for: currentMode) : resolvedPanel
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
            hapticFrequency: clamped(hapticFrequency, to: MeditationSettings.hapticFrequencyRange),
            hapticCurveTiming: clamped(hapticCurveTiming, to: MeditationSettings.hapticCurveTimingRange)
        )
    }

    private var activeAnimationMode: MeditationAnimationMode {
        animationMode(for: panel)
    }

    private var hapticsLoopID: HapticsLoopID {
        HapticsLoopID(startedAt: startedAt, settings: settings, sceneIsActive: scenePhase == .active)
    }

    var body: some View {
        let activeMode = activeAnimationMode

        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let activeTransition = panelTransition(width: width)
            let sceneTransition = sceneTransition(for: activeTransition)
            let chromeContentStates = panelContentStates(for: activeTransition)
            let breathChromeVisible = !configurationVisible && (chromeVisible || activeTransition != nil)
            let chromeHorizontalPadding = max(12, min(22, width * 0.04))

            ZStack {
                MeditationScene(
                    mode: activeMode,
                    transition: sceneTransition,
                    startedAt: startedAt,
                    timeline: timeline,
                    reduceMotion: reduceMotion
                )
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(swipeGesture(width: width))
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

                if breathChromeVisible {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()

                            ConfigButton {
                                presentConfiguration()
                            }
                        }
                        .padding(.top, 4)

                        Spacer()

                        ZStack {
                            ForEach(chromeContentStates) { state in
                                panelChromeContent(state)
                                    .opacity(state.opacity)
                                    .offset(x: state.offsetX)
                            }
                        }
                    }
                    .transition(.opacity)
                    .padding(.horizontal, chromeHorizontalPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }

                if configurationVisible {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissConfiguration()
                        }

                    ConfigurationPanel(
                        breathsPerMinute: $breathsPerMinute,
                        hapticIntensity: $hapticIntensity,
                        hapticFrequency: $hapticFrequency,
                        hapticCurveTiming: $hapticCurveTiming
                    )
                    .padding(.horizontal, chromeHorizontalPadding)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            if let launchOverride = MeditationPanel.launchOverride() {
                if launchOverride == .configuration {
                    presentConfiguration(animated: false)
                } else {
                    setPanel(launchOverride, reveal: false)
                }
            } else if MeditationPanel(rawValue: panelRawValue) == .configuration {
                setPanel(MeditationPanel.panel(for: currentMode), reveal: false)
                presentConfiguration(animated: false)
            }

            startedAt = Date().addingTimeInterval(-BreathingTimeline.initialElapsedOffset)
            updateMeditationActive(true)
            haptics.startLoopingPattern(for: timeline, elapsed: BreathingTimeline.initialElapsedOffset)
            revealChromeTemporarily()
        }
        .onOpenURL { url in
            guard let panel = MeditationPanel.appURLPanel(url) else {
                return
            }

            if panel == .configuration {
                presentConfiguration()
            } else {
                dismissConfiguration()
                setPanel(panel)
            }
        }
        .task(id: hapticsLoopID) {
            guard hapticsLoopID.sceneIsActive else {
                haptics.stop()
                return
            }

            haptics.startLoopingPattern(for: settings.timeline, elapsed: Date().timeIntervalSince(startedAt))
            await runHapticsLoop(startedAt: startedAt, settings: settings)
        }
        .task {
            await runDiagnosticsLoop()
        }
        .onChange(of: settings) { oldSettings, newSettings in
            preserveBreathPhaseIfNeeded(from: oldSettings, to: newSettings)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            updateMeditationActive(true)
            haptics.startLoopingPattern(for: timeline, elapsed: Date().timeIntervalSince(startedAt))
        }
        .task(id: chromeFadeToken) {
            guard !configurationVisible else {
                return
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)

            guard !Task.isCancelled, !configurationVisible else {
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

    @ViewBuilder
    private func panelChromeContent(_ state: PanelContentState) -> some View {
        if let mode = state.panel.animationMode {
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                BreathCaption(
                    mode: mode,
                    snapshot: timeline.snapshot(at: context.date, startedAt: startedAt)
                )
            }
        }
    }

    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 38)
            .updating($liveSwipeTranslation) { value, state, transaction in
                transaction.animation = nil
                state = interactiveTranslation(for: value)
            }
            .onEnded { value in
                settleSwipe(value, width: width)
            }
    }

    private func interactiveTranslation(for value: DragGesture.Value) -> CGFloat {
        guard settlingPanelTransition == nil, !configurationVisible else {
            return 0
        }

        let horizontal = value.translation.width
        let vertical = value.translation.height

        guard abs(horizontal) > abs(vertical), abs(horizontal) > 8 else {
            return 0
        }

        guard targetPanel(for: horizontal) != nil else {
            return horizontal * 0.18
        }

        return horizontal
    }

    private func settleSwipe(_ value: DragGesture.Value, width: CGFloat) {
        guard settlingPanelTransition == nil, !configurationVisible else {
            return
        }

        let horizontal = value.translation.width
        let vertical = value.translation.height
        let predictedHorizontal = value.predictedEndTranslation.width
        let decisiveHorizontal = abs(predictedHorizontal) > abs(horizontal) ? predictedHorizontal : horizontal

        guard abs(horizontal) > abs(vertical), abs(horizontal) > 18 else {
            return
        }

        guard let targetPanel = targetPanel(for: decisiveHorizontal),
              let direction = PanelSwipeDirection(translation: decisiveHorizontal) else {
            revealChromeTemporarily()
            return
        }

        let currentProgress = min(0.98, max(0, abs(horizontal) / max(width, 1)))
        let predictedProgress = min(1, max(0, abs(predictedHorizontal) / max(width, 1)))
        let shouldCommit = currentProgress >= 0.24 || predictedProgress >= 0.34 || abs(predictedHorizontal) > 180
        let startingProgress = max(0.02, currentProgress)
        let endProgress: CGFloat = shouldCommit ? 1 : 0
        let transition = PanelTransition(
            fromPanel: panel,
            toPanel: targetPanel,
            direction: direction,
            progress: startingProgress
        )
        let token = panelTransitionToken + 1

        panelTransitionToken = token
        settlingPanelTransition = transition
        revealChromeTemporarily()

        withAnimation(.easeOut(duration: 0.28)) {
            settlingPanelTransition = transition.withProgress(endProgress)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard panelTransitionToken == token else {
                return
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                if shouldCommit {
                    setPanel(targetPanel, reveal: false)
                }

                settlingPanelTransition = nil
            }

            if shouldCommit {
                revealChromeTemporarily()
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
    }

    private func runDiagnosticsLoop() async {
        while !Task.isCancelled {
            diagnostics.refresh()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
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

    private func presentConfiguration(animated: Bool = true) {
        let update = {
            configurationVisible = true
            chromeVisible = true
            chromeFadeToken += 1
        }

        if animated {
            withAnimation(.easeOut(duration: 0.22), update)
        } else {
            update()
        }
    }

    private func dismissConfiguration(animated: Bool = true) {
        let update = {
            configurationVisible = false
            chromeVisible = true
            chromeFadeToken += 1
        }

        if animated {
            withAnimation(.easeOut(duration: 0.20), update)
        } else {
            update()
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

    private func preserveBreathPhaseIfNeeded(from oldSettings: MeditationSettings, to newSettings: MeditationSettings) {
        guard oldSettings.breathsPerMinute != newSettings.breathsPerMinute else {
            return
        }

        let now = Date()
        let oldElapsed = max(0, now.timeIntervalSince(startedAt))
        let oldCycleDuration = oldSettings.timeline.cycleDuration
        let newCycleDuration = newSettings.timeline.cycleDuration
        let completedCycles = floor(oldElapsed / oldCycleDuration)
        let cycleProgress = (oldElapsed / oldCycleDuration).truncatingRemainder(dividingBy: 1)
        let adjustedElapsed = (completedCycles + cycleProgress) * newCycleDuration

        startedAt = now.addingTimeInterval(-adjustedElapsed)
    }

    private func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func animationMode(for panel: MeditationPanel) -> MeditationAnimationMode {
        panel.animationMode ?? currentMode
    }

    private func targetPanel(for translation: CGFloat) -> MeditationPanel? {
        if translation < 0 {
            return panel.next
        }

        if translation > 0 {
            return panel.previous
        }

        return nil
    }

    private func panelTransition(width: CGFloat) -> PanelTransition? {
        if let settlingPanelTransition {
            return settlingPanelTransition
        }

        guard let targetPanel = targetPanel(for: liveSwipeTranslation),
              let direction = PanelSwipeDirection(translation: liveSwipeTranslation) else {
            return nil
        }

        return PanelTransition(
            fromPanel: panel,
            toPanel: targetPanel,
            direction: direction,
            progress: min(0.98, max(0, abs(liveSwipeTranslation) / max(width, 1)))
        )
    }

    private func sceneTransition(for transition: PanelTransition?) -> MeditationSceneTransition? {
        guard let transition else {
            return nil
        }

        let fromMode = animationMode(for: transition.fromPanel)
        let toMode = animationMode(for: transition.toPanel)

        guard fromMode != toMode else {
            return nil
        }

        return MeditationSceneTransition(
            fromMode: fromMode,
            toMode: toMode,
            direction: transition.direction,
            progress: transition.progress
        )
    }

    private func panelContentStates(for transition: PanelTransition?) -> [PanelContentState] {
        guard let transition else {
            return [PanelContentState(panel: panel, opacity: 1, offsetX: 0)]
        }

        return [transition.fromPanel, transition.toPanel].compactMap { candidate in
            panelContentState(for: candidate, transition: transition)
        }
    }

    private func panelContentState(for candidate: MeditationPanel, transition: PanelTransition) -> PanelContentState? {
        let progress = max(0, min(1, transition.progress))
        let opacity: Double
        let offsetX: CGFloat

        if candidate == transition.fromPanel {
            opacity = Double(1 - progress)
            offsetX = transition.direction.sign * progress * 34
        } else if candidate == transition.toPanel {
            opacity = Double(progress)
            offsetX = -transition.direction.sign * (1 - progress) * 34
        } else {
            return nil
        }

        return PanelContentState(panel: candidate, opacity: opacity, offsetX: offsetX)
    }

}

private struct HapticsLoopID: Equatable {
    let startedAt: Date
    let settings: MeditationSettings
    let sceneIsActive: Bool
}

private struct PanelContentState: Identifiable, Equatable {
    let panel: MeditationPanel
    let opacity: Double
    let offsetX: CGFloat

    var id: Int { panel.id }
}

private enum PanelSwipeDirection: Equatable {
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

    init?(from: MeditationPanel, to: MeditationPanel) {
        if to.rawValue > from.rawValue {
            self = .next
        } else if to.rawValue < from.rawValue {
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

    var incomingFadeEdge: SceneFadeEdge {
        switch self {
        case .previous:
            .trailing
        case .next:
            .leading
        }
    }

    var outgoingFadeEdge: SceneFadeEdge {
        switch self {
        case .previous:
            .leading
        case .next:
            .trailing
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

private struct PanelTransition: Equatable {
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

private struct MeditationSceneTransition: Equatable {
    let fromMode: MeditationAnimationMode
    let toMode: MeditationAnimationMode
    let direction: PanelSwipeDirection
    let progress: CGFloat
}

private struct MeditationScene: View {
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

private struct DiagnosticsOverlay: View {
    let snapshot: FrameDiagnosticsSnapshot

    var body: some View {
        Text(text)
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.25))
    }

    private var text: String {
        let cpuText = snapshot.cpuUsagePercent.map { String(format: "CPU %.0f%%", $0) } ?? "CPU n/a"

        guard let thermalText = snapshot.thermalState.diagnosticTitle else {
            return cpuText
        }

        return "\(cpuText) (\(thermalText))"
    }
}

private extension ProcessInfo.ThermalState {
    var diagnosticTitle: String? {
        switch self {
        case .nominal:
            nil
        case .fair:
            "WARM"
        case .serious:
            "HOT"
        case .critical:
            "CRIT"
        @unknown default:
            nil
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

private struct ConfigurationPanel: View {
    @Binding var breathsPerMinute: Double
    @Binding var hapticIntensity: Double
    @Binding var hapticFrequency: Double
    @Binding var hapticCurveTiming: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Configuration", systemImage: "slider.horizontal.3")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))

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

            ConfigurationSlider(
                title: "Pulse timing",
                valueText: timingText,
                systemImage: "arrow.left.and.right",
                value: $hapticCurveTiming,
                range: MeditationSettings.hapticCurveTimingRange,
                step: 0.05,
                accent: Color(red: 0.80, green: 0.92, blue: 1.0)
            )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: 380, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 18)
        .accessibilityElement(children: .contain)
    }

    private var timingText: String {
        let percent = Int((abs(hapticCurveTiming) * 100).rounded())

        if percent == 0 {
            return "Centered"
        }

        return hapticCurveTiming < 0 ? "Early \(percent)%" : "Late \(percent)%"
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24)

                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer()

                Text(valueText)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Slider(value: $value, in: range, step: step)
                .tint(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct ConfigButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.18), in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open configuration")
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
