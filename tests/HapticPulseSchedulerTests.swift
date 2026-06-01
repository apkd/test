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
        let expectedPulseUpperBound = Int(timeline.peakHapticPulsesPerSecond * timeline.cycleDuration / Double.pi) + 2
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
    func stopResetsSchedulerState() {
        let timeline = BreathingTimeline()
        let startDate = Date(timeIntervalSinceReferenceDate: 3_000)
        var scheduler = HapticPulseScheduler()

        _ = scheduler.update(with: timeline.snapshot(elapsed: 0), at: startDate)
        scheduler.stop()

        #expect(scheduler.isInhaling == false)
    }
}
