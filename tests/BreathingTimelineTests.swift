import Foundation
import Testing
@testable import TestApp

struct BreathingTimelineTests {
    @Test
    func defaultCycleUsesSevenBreathsPerMinute() {
        let timeline = BreathingTimeline()
        let initialSnapshot = timeline.snapshot(elapsed: BreathingTimeline.initialElapsedOffset)

        #expect(abs(timeline.cycleDuration - 60.0 / 7.0) < 0.000_001)
        #expect(BreathingTimeline.initialElapsedOffset > 0)
        #expect(BreathingTimeline.initialElapsedOffset < timeline.cycleDuration * 0.25)
        #expect(initialSnapshot.phase == .inhale)
        #expect(initialSnapshot.hapticRate > 0)
        #expect(initialSnapshot.hapticIntensity == MeditationSettings.defaultHapticIntensity)
        #expect(initialSnapshot.hapticIntensityScale == 1)
        #expect(initialSnapshot.hapticFrequency == MeditationSettings.defaultHapticFrequency)
    }

    @Test
    func sineModelMapsFirstHalfToInhaleAndSecondHalfToExhale() {
        let timeline = BreathingTimeline()

        let start = timeline.snapshot(elapsed: 0)
        let inhalePeak = timeline.snapshot(elapsed: timeline.cycleDuration * 0.25)
        let exhaleStart = timeline.snapshot(elapsed: timeline.cycleDuration * 0.5)
        let exhaleMidpoint = timeline.snapshot(elapsed: timeline.cycleDuration * 0.75)

        #expect(start.phase == .inhale)
        #expect(start.hapticRate == 0)
        #expect(inhalePeak.phase == .inhale)
        #expect(abs(inhalePeak.hapticRate - 1) < 0.000_001)
        #expect(exhaleStart.phase == .exhale)
        #expect(exhaleStart.hapticRate == 0)
        #expect(exhaleMidpoint.phase == .exhale)
        #expect(exhaleMidpoint.hapticRate == 0)
    }

    @Test
    func hapticRateAcceleratesThenDeceleratesDuringInhale() {
        let timeline = BreathingTimeline()

        let earlyInhale = timeline.snapshot(elapsed: timeline.cycleDuration * 0.125)
        let inhalePeak = timeline.snapshot(elapsed: timeline.cycleDuration * 0.25)
        let lateInhale = timeline.snapshot(elapsed: timeline.cycleDuration * 0.375)

        #expect(earlyInhale.hapticPulsesPerSecond > 0)
        #expect(earlyInhale.hapticPulsesPerSecond < inhalePeak.hapticPulsesPerSecond)
        #expect(lateInhale.hapticPulsesPerSecond < inhalePeak.hapticPulsesPerSecond)
        #expect(abs(earlyInhale.hapticPulsesPerSecond - lateInhale.hapticPulsesPerSecond) < 0.000_001)
        #expect(abs(inhalePeak.hapticPulsesPerSecond - 20) < 0.000_001)
    }

    @Test
    func hapticIntensityCanDisablePulses() {
        let timeline = BreathingTimeline(hapticIntensity: 0)
        let inhalePeak = timeline.snapshot(elapsed: timeline.cycleDuration * 0.25)

        #expect(inhalePeak.hapticRate > 0)
        #expect(inhalePeak.hapticIntensity == 0)
        #expect(inhalePeak.hapticIntensityScale == 0)
        #expect(inhalePeak.hapticPulsesPerSecond == 0)
    }

    @Test
    func hapticIntensityDefaultMatchesPreviousBaselineAndCanDoubleIt() {
        let baseline = BreathingTimeline(hapticIntensity: 0.5).snapshot(elapsed: 1)
        let doubled = BreathingTimeline(hapticIntensity: 1).snapshot(elapsed: 1)

        #expect(baseline.hapticIntensityScale == 1)
        #expect(doubled.hapticIntensityScale == 2)
    }

    @Test
    func hapticFrequencyControlsPulseRate() {
        let quiet = BreathingTimeline(hapticFrequency: 0)
        let defaultFrequency = BreathingTimeline(hapticFrequency: 0.5)
        let maximum = BreathingTimeline(hapticFrequency: 1)

        #expect(quiet.snapshot(elapsed: quiet.cycleDuration * 0.25).hapticPulsesPerSecond == 0)
        #expect(abs(defaultFrequency.snapshot(elapsed: defaultFrequency.cycleDuration * 0.25).hapticPulsesPerSecond - 20) < 0.000_001)
        #expect(abs(maximum.snapshot(elapsed: maximum.cycleDuration * 0.25).hapticPulsesPerSecond - 40) < 0.000_001)
    }

    @Test
    func hapticTimingCurveCanMovePulseEmphasisEarlierOrLater() {
        let earlyTiming = BreathingTimeline(hapticCurveTiming: -1)
        let lateTiming = BreathingTimeline(hapticCurveTiming: 1)
        let earlySample = 0.125
        let lateSample = 0.375

        #expect(earlyTiming.snapshot(elapsed: earlyTiming.cycleDuration * earlySample).hapticRate > earlyTiming.snapshot(elapsed: earlyTiming.cycleDuration * lateSample).hapticRate)
        #expect(lateTiming.snapshot(elapsed: lateTiming.cycleDuration * lateSample).hapticRate > lateTiming.snapshot(elapsed: lateTiming.cycleDuration * earlySample).hapticRate)
    }

    @Test
    func hapticFocusCurveNarrowsPulseAroundPeak() {
        let baseline = BreathingTimeline()
        let focused = BreathingTimeline(hapticCurveFocus: 1)
        let shoulderElapsed = baseline.cycleDuration * 0.125
        let peakElapsed = baseline.cycleDuration * 0.25

        #expect(focused.snapshot(elapsed: shoulderElapsed).hapticRate < baseline.snapshot(elapsed: shoulderElapsed).hapticRate)
        #expect(abs(focused.snapshot(elapsed: peakElapsed).hapticRate - 1) < 0.000_001)
    }

    @Test
    func hapticFloorCurveRaisesMinimumInhaleRate() {
        let timeline = BreathingTimeline(hapticCurveFloor: 1)
        let start = timeline.snapshot(elapsed: 0)

        #expect(abs(start.hapticRate - BreathingTimeline.hapticCurveMaximumFloor) < 0.000_001)
    }

    @Test
    func meditationSettingsBuildsConfiguredTimeline() {
        let settings = MeditationSettings(
            breathsPerMinute: 9.5,
            hapticIntensity: 0.4,
            hapticFrequency: 0.25,
            hapticCurveTiming: -0.2,
            hapticCurveFocus: 0.3,
            hapticCurveFloor: 0.4
        )
        let timeline = settings.timeline
        let inhalePeak = timeline.snapshot(elapsed: timeline.cycleDuration * 0.25)

        #expect(abs(timeline.cycleDuration - 60.0 / 9.5) < 0.000_001)
        #expect(abs(inhalePeak.hapticIntensity - 0.4) < 0.000_001)
        #expect(abs(inhalePeak.hapticIntensityScale - 0.8) < 0.000_001)
        #expect(inhalePeak.hapticPulsesPerSecond > 0)
        #expect(timeline.hapticCurveTiming == -0.2)
        #expect(timeline.hapticCurveFocus == 0.3)
        #expect(timeline.hapticCurveFloor == 0.4)
    }

    @Test
    func hapticRateIsZeroThroughoutExhale() {
        let timeline = BreathingTimeline()

        for progress in [0.50, 0.625, 0.75, 0.875, 0.999] {
            let snapshot = timeline.snapshot(elapsed: timeline.cycleDuration * progress)

            #expect(snapshot.phase == .exhale)
            #expect(snapshot.hapticRate == 0)
            #expect(snapshot.hapticPulsesPerSecond == 0)
        }
    }

    @Test
    func visualBreathExpandsThroughInhaleAndReleasesThroughExhale() {
        let timeline = BreathingTimeline()

        let rest = timeline.snapshot(elapsed: 0)
        let full = timeline.snapshot(elapsed: timeline.cycleDuration * 0.5)
        let released = timeline.snapshot(elapsed: timeline.cycleDuration)

        #expect(rest.breathAmount == 0)
        #expect(abs(full.breathAmount - 1) < 0.000_001)
        #expect(released.breathAmount == 0)
    }

    @Test
    func prototypeOffersTheThreeRequestedAnimationModes() {
        #expect(MeditationAnimationMode.defaultMode == .breathingHorizon)
        #expect(MeditationAnimationMode.allCases.map(\.title) == [
            "Silk ribbon",
            "Breathing horizon",
            "Ink bloom",
        ])
    }

    @Test
    func launchEnvironmentCanSelectInitialAnimationMode() {
        let key = MeditationAnimationMode.launchEnvironmentKey

        #expect(MeditationAnimationMode.launchMode(environment: [key: "silk-ribbon"]) == .silkRibbon)
        #expect(MeditationAnimationMode.launchMode(environment: [key: "breathing-horizon"]) == .breathingHorizon)
        #expect(MeditationAnimationMode.launchMode(environment: [key: "ink-bloom"]) == .inkBloom)
        #expect(MeditationAnimationMode.launchMode(environment: [key: "Bloom"]) == .inkBloom)
        #expect(MeditationAnimationMode.launchMode(environment: [key: "unknown"]) == .breathingHorizon)
        #expect(MeditationAnimationMode.launchMode(environment: [:]) == .breathingHorizon)
    }

    @Test
    func animationModeOrderIsStable() {
        #expect(MeditationAnimationMode.allCases == [
            .silkRibbon,
            .breathingHorizon,
            .inkBloom,
        ])
    }

    @Test
    func configurationIsTheFirstCarouselPanel() {
        #expect(MeditationPanel.allCases.map(\.title) == [
            "Configuration",
            "Breathing horizon",
            "Silk ribbon",
            "Ink bloom",
        ])
        #expect(MeditationPanel.launchPanel(environment: [:]) == .breathingHorizon)
        #expect(MeditationPanel.launchPanel(environment: [
            MeditationAnimationMode.launchEnvironmentKey: "config",
        ]) == .configuration)
        #expect(MeditationPanel.launchOverride(environment: [:]) == nil)
        #expect(MeditationPanel.breathingHorizon.next == .silkRibbon)
        #expect(MeditationPanel.configuration.previous == nil)
        #expect(MeditationPanel.inkBloom.next == nil)
        #expect(MeditationPanel.silkRibbon.previous == .breathingHorizon)
        #expect(MeditationPanel.silkRibbon.next == .inkBloom)
    }

    @Test
    func appURLCanSelectSmokeTestPanels() throws {
        #expect(MeditationPanel.urlScheme == "testapp")
        #expect(MeditationPanel.appURLPanel(try #require(URL(string: "testapp://panel/config"))) == .configuration)
        #expect(MeditationPanel.appURLPanel(try #require(URL(string: "testapp://screen/breathing-horizon"))) == .breathingHorizon)
        #expect(MeditationPanel.appURLPanel(try #require(URL(string: "testapp://mode/silk-ribbon"))) == .silkRibbon)
        #expect(MeditationPanel.appURLPanel(try #require(URL(string: "testapp://smoke/ink-bloom"))) == .inkBloom)
        #expect(MeditationPanel.appURLPanel(try #require(URL(string: "testapp://panel/unknown"))) == nil)
        #expect(MeditationPanel.appURLPanel(try #require(URL(string: "other://panel/config"))) == nil)
    }

    @Test
    func persistenceKeysAreStable() {
        #expect(MeditationPersistenceKey.panelRawValue == "meditation.panel.rawValue")
        #expect(MeditationPersistenceKey.lastAnimationModeRawValue == "meditation.lastAnimationMode.rawValue")
        #expect(MeditationPersistenceKey.breathsPerMinute == "meditation.breathsPerMinute")
        #expect(MeditationPersistenceKey.hapticIntensity == "meditation.hapticIntensity")
        #expect(MeditationPersistenceKey.hapticFrequency == "meditation.hapticFrequency")
        #expect(MeditationPersistenceKey.hapticCurveTiming == "meditation.hapticCurve.timing")
        #expect(MeditationPersistenceKey.hapticCurveFocus == "meditation.hapticCurve.focus")
        #expect(MeditationPersistenceKey.hapticCurveFloor == "meditation.hapticCurve.floor")
    }
}
