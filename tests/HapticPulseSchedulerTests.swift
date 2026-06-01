import Foundation
import Testing
@testable import TestApp

struct HapticPulseSchedulerTests {
    @Test
    func schedulerStartsAndEndsInhaleAroundPositiveSineWindow() {
        let timeline = BreathingTimeline()
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var scheduler = HapticPulseScheduler()

        let startEvents = scheduler.update(with: timeline.snapshot(elapsed: 0), at: startDate)
        let exhaleEvents = scheduler.update(
            with: timeline.snapshot(elapsed: timeline.cycleDuration * 0.5),
            at: startDate.addingTimeInterval(timeline.cycleDuration * 0.5)
        )

        #expect(startEvents == [
            .inhaleStarted,
            .pulse(intensity: HapticPulseScheduler.inhaleStartPulseIntensity),
        ])
        #expect(exhaleEvents == [.inhaleEnded])
        #expect(scheduler.isInhaling == false)
    }

    @Test
    func schedulerEmitsNoticeablePulsesDuringInhaleOnly() {
        let timeline = BreathingTimeline()
        let startDate = Date(timeIntervalSinceReferenceDate: 2_000)
        var scheduler = HapticPulseScheduler()
        let inhaleDuration = timeline.cycleDuration * 0.5
        let expectedPulseUpperBound = Int(timeline.peakHapticPulsesPerSecond * timeline.hapticFrequency * timeline.cycleDuration / Double.pi) + 3
        var pulseCount = 0
        var exhalePulseCount = 0

        for step in 0...Int(timeline.cycleDuration / 0.024) {
            let elapsed = Double(step) * 0.024
            let events = scheduler.update(
                with: timeline.snapshot(elapsed: elapsed),
                at: startDate.addingTimeInterval(elapsed)
            )

            for event in events {
                if case let .pulse(intensity) = event {
                    #expect(intensity >= HapticPulseScheduler.minimumPulseIntensity)
                    #expect(intensity <= HapticPulseScheduler.maximumPulseIntensity)

                    if elapsed < inhaleDuration {
                        pulseCount += 1
                    } else {
                        exhalePulseCount += 1
                    }
                }
            }
        }

        #expect(pulseCount > 0)
        #expect(pulseCount <= expectedPulseUpperBound)
        #expect(exhalePulseCount == 0)
    }

    @Test
    func schedulerCanEmitMultiplePulsesForOneLargeUpdate() {
        let timeline = BreathingTimeline(hapticFrequency: 1)
        let startDate = Date(timeIntervalSinceReferenceDate: 2_500)
        let peakElapsed = timeline.cycleDuration * 0.25
        var scheduler = HapticPulseScheduler()

        _ = scheduler.update(with: timeline.snapshot(elapsed: peakElapsed), at: startDate)
        let events = scheduler.update(
            with: timeline.snapshot(elapsed: peakElapsed + 0.1),
            at: startDate.addingTimeInterval(0.1)
        )

        let pulseCount = events.reduce(0) { count, event in
            if case .pulse = event {
                return count + 1
            }

            return count
        }

        #expect(pulseCount >= 2)
    }

    @Test
    func pulseIntensityFadesByFortyPercentWithRate() {
        #expect(HapticPulseScheduler.minimumPulseIntensity == 0.60)
        #expect(HapticPulseScheduler.maximumPulseIntensity == 1.0)
        #expect(abs((HapticPulseScheduler.maximumPulseIntensity - HapticPulseScheduler.minimumPulseIntensity) - 0.40) < 0.000_001)
    }

    @Test
    func stopResetsSchedulerState() {
        let timeline = BreathingTimeline()
        let startDate = Date(timeIntervalSinceReferenceDate: 3_000)
        var scheduler = HapticPulseScheduler()

        _ = scheduler.update(with: timeline.snapshot(elapsed: 0), at: startDate)
        scheduler.stop()

        #expect(scheduler.isInhaling == false)
    }

    @Test
    func schedulerDoesNotEmitPulsesWhenHapticsAreDisabled() {
        let timeline = BreathingTimeline(hapticIntensity: 0)
        let startDate = Date(timeIntervalSinceReferenceDate: 4_000)
        var scheduler = HapticPulseScheduler()
        var pulseCount = 0

        for step in 0...Int(timeline.cycleDuration / 0.024) {
            let elapsed = Double(step) * 0.024
            let events = scheduler.update(
                with: timeline.snapshot(elapsed: elapsed),
                at: startDate.addingTimeInterval(elapsed)
            )

            for event in events {
                if case .pulse = event {
                    pulseCount += 1
                }
            }
        }

        #expect(pulseCount == 0)
    }

    @Test
    func schedulerKeepsOpeningPulseWhenFrequencyIsZero() {
        let timeline = BreathingTimeline(hapticFrequency: 0)
        let startDate = Date(timeIntervalSinceReferenceDate: 5_000)
        var scheduler = HapticPulseScheduler()

        let startEvents = scheduler.update(with: timeline.snapshot(elapsed: 0), at: startDate)
        let laterEvents = scheduler.update(
            with: timeline.snapshot(elapsed: 0.5),
            at: startDate.addingTimeInterval(0.5)
        )

        #expect(startEvents == [
            .inhaleStarted,
            .pulse(intensity: HapticPulseScheduler.inhaleStartPulseIntensity),
        ])
        #expect(laterEvents == [])
    }
}
