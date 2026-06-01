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
    func animationModesCycleForSwipeNavigation() {
        #expect(MeditationAnimationMode.silkRibbon.next == .breathingHorizon)
        #expect(MeditationAnimationMode.breathingHorizon.next == .inkBloom)
        #expect(MeditationAnimationMode.inkBloom.next == .silkRibbon)

        #expect(MeditationAnimationMode.silkRibbon.previous == .inkBloom)
        #expect(MeditationAnimationMode.breathingHorizon.previous == .silkRibbon)
        #expect(MeditationAnimationMode.inkBloom.previous == .breathingHorizon)
    }
}
