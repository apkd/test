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
        .task {
            await runSmokeControlLoopIfNeeded()
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

            withAnimation(.easeOut(duration: 1.8)) {
                chromeVisible = false
            }
        }
        .onChange(of: panel) { _, _ in
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

    private func runSmokeControlLoopIfNeeded() async {
        guard ProcessInfo.processInfo.environment[MeditationAnimationMode.smokeControlEnvironmentKey] == "1",
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let controlURL = documentsURL.appendingPathComponent(MeditationAnimationMode.smokeControlFileName)
        var lastRawValue = ""

        while !Task.isCancelled {
            if let rawValue = try? String(contentsOf: controlURL, encoding: .utf8),
               rawValue != lastRawValue,
               let command = smokeControlCommand(rawValue) {
                lastRawValue = rawValue
                applySmokeControlCommand(command)
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func smokeControlCommand(_ rawValue: String) -> SmokeControlCommand? {
        let parts = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split { separator in
                separator.isWhitespace || separator == "|" || separator == "," || separator == ";"
            }

        guard let panelValue = parts.first,
              let panel = MeditationPanel.smokeControlPanel(String(panelValue)) else {
            return nil
        }

        let cycleProgress = parts
            .dropFirst()
            .compactMap { Double($0) }
            .first
            .map { min(0.999, max(0, $0)) }

        return SmokeControlCommand(panel: panel, cycleProgress: cycleProgress)
    }

    private func applySmokeControlCommand(_ command: SmokeControlCommand) {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            if command.panel == .configuration {
                presentConfiguration(animated: false)
            } else {
                dismissConfiguration(animated: false)
                setPanel(command.panel, reveal: true)
            }

            if let cycleProgress = command.cycleProgress {
                startedAt = Date().addingTimeInterval(-settings.timeline.cycleDuration * cycleProgress)
            }
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

private struct SmokeControlCommand: Equatable {
    let panel: MeditationPanel
    let cycleProgress: Double?
}

private struct PanelContentState: Identifiable, Equatable {
    let panel: MeditationPanel
    let opacity: Double
    let offsetX: CGFloat

    var id: Int { panel.id }
}
