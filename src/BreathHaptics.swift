import Foundation
import SwiftUI

#if os(iOS)
import CoreHaptics
import UIKit
#endif

@MainActor
final class BreathHapticCoordinator: ObservableObject {
    private var scheduler = HapticPulseScheduler()

    #if os(iOS)
    private var generator: UIImpactFeedbackGenerator?
    private var coreHapticEngine: CHHapticEngine?
    private var advancedPlayer: CHHapticAdvancedPatternPlayer?
    private var patternSignature: HapticPatternSignature?
    private var latestTimeline: BreathingTimeline?
    private var patternReferenceDate: Date?
    #endif

    func startLoopingPattern(for timeline: BreathingTimeline, elapsed: TimeInterval) {
        #if os(iOS)
        startCoreHapticLoop(for: timeline, elapsed: elapsed)
        #endif
    }

    func update(with snapshot: BreathingSnapshot, at date: Date) {
        #if os(iOS)
        guard advancedPlayer == nil else {
            return
        }
        #endif

        for event in scheduler.update(with: snapshot, at: date) {
            switch event {
            case .inhaleStarted:
                beginInhale()
            case .inhaleEnded:
                endInhale()
            case let .pulse(intensity):
                playPulse(intensity: intensity)
            }
        }
    }

    func stop() {
        scheduler.stop()

        #if os(iOS)
        generator = nil
        try? advancedPlayer?.stop(atTime: CHHapticTimeImmediate)
        advancedPlayer = nil
        patternSignature = nil
        latestTimeline = nil
        patternReferenceDate = nil
        stopCoreHaptics()
        #endif
    }

    private func beginInhale() {
        #if os(iOS)
        generator = UIImpactFeedbackGenerator(style: .medium)
        generator?.prepare()
        _ = ensureCoreHapticsStarted()
        #endif
    }

    private func endInhale() {
        #if os(iOS)
        generator = nil
        #endif
    }

    private func playPulse(intensity: Double) {
        #if os(iOS)
        let clampedIntensity = max(0, min(1, intensity))

        guard !playCorePulse(intensity: clampedIntensity) else {
            return
        }

        generator?.impactOccurred(intensity: CGFloat(clampedIntensity))
        generator?.prepare()
        #endif
    }

    #if os(iOS)
    private func ensureCoreHapticsStarted() -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return false
        }

        do {
            if coreHapticEngine == nil {
                let engine = try CHHapticEngine()
                engine.stoppedHandler = { [weak self] _ in
                    Task { @MainActor in
                        self?.coreHapticEngine = nil
                        self?.advancedPlayer = nil
                        self?.patternSignature = nil
                    }
                }
                engine.resetHandler = { [weak self] in
                    Task { @MainActor in
                        self?.restartCoreHapticLoopAfterReset()
                    }
                }
                coreHapticEngine = engine
            }

            try coreHapticEngine?.start()
            return coreHapticEngine != nil
        } catch {
            coreHapticEngine = nil
            return false
        }
    }

    private func startCoreHapticLoop(for timeline: BreathingTimeline, elapsed: TimeInterval) {
        latestTimeline = timeline
        patternReferenceDate = Date().addingTimeInterval(-elapsed)

        let signature = HapticPatternSignature(timeline: timeline)
        guard signature.isEnabled else {
            try? advancedPlayer?.stop(atTime: CHHapticTimeImmediate)
            advancedPlayer = nil
            patternSignature = signature
            return
        }

        guard patternSignature != signature || advancedPlayer == nil else {
            return
        }

        try? advancedPlayer?.stop(atTime: CHHapticTimeImmediate)
        advancedPlayer = nil
        patternSignature = signature

        guard ensureCoreHapticsStarted(), let coreHapticEngine else {
            return
        }

        do {
            let pattern = try makeBreathPattern(timeline: timeline)
            let player = try coreHapticEngine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            player.loopEnd = timeline.cycleDuration
            try player.seek(toOffset: max(0, elapsed).truncatingRemainder(dividingBy: timeline.cycleDuration))
            try player.start(atTime: CHHapticTimeImmediate)
            advancedPlayer = player
            scheduler.stop()
            generator = nil
        } catch {
            advancedPlayer = nil
            patternSignature = nil
        }
    }

    private func restartCoreHapticLoopAfterReset() {
        guard let latestTimeline else {
            return
        }

        let elapsed = patternReferenceDate.map { Date().timeIntervalSince($0) } ?? 0
        advancedPlayer = nil
        patternSignature = nil
        coreHapticEngine = nil
        startCoreHapticLoop(for: latestTimeline, elapsed: elapsed)
    }

    private func makeBreathPattern(timeline: BreathingTimeline) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        let startSnapshot = timeline.snapshot(elapsed: 0)

        if startSnapshot.hapticIntensityScale > 0 {
            events.append(transientEvent(relativeTime: 0, intensity: HapticPulseScheduler.inhaleStartPulseIntensity * startSnapshot.hapticIntensityScale))
        }

        let step = 1.0 / 120.0
        var elapsed = step
        var accumulator = 0.0
        var previousElapsed = 0.0

        while elapsed < timeline.cycleDuration * 0.5 {
            let snapshot = timeline.snapshot(elapsed: elapsed)
            let delta = elapsed - previousElapsed
            previousElapsed = elapsed
            accumulator += delta * snapshot.hapticPulsesPerSecond

            while accumulator >= 1 {
                accumulator -= 1
                let intensity = HapticPulseScheduler.minimumPulseIntensity
                    + (HapticPulseScheduler.maximumPulseIntensity - HapticPulseScheduler.minimumPulseIntensity) * snapshot.hapticRate
                events.append(transientEvent(relativeTime: elapsed, intensity: intensity * snapshot.hapticIntensityScale))
            }

            elapsed += step
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func transientEvent(relativeTime: TimeInterval, intensity: Double) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(max(0, min(1, intensity)))),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.34),
            ],
            relativeTime: relativeTime
        )
    }

    private func playCorePulse(intensity: Double) -> Bool {
        guard ensureCoreHapticsStarted(), let coreHapticEngine else {
            return false
        }

        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.34),
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try coreHapticEngine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    private func stopCoreHaptics() {
        coreHapticEngine?.stop(completionHandler: nil)
        coreHapticEngine = nil
    }
    #endif
}

#if os(iOS)
private struct HapticPatternSignature: Equatable {
    let breathsPerMinute: Double
    let peakHapticPulsesPerSecond: Double
    let hapticIntensity: Double
    let hapticFrequency: Double
    let hapticCurveSmoothBlend: Double
    let hapticCurvePeakBlend: Double
    let hapticCurveEarlyBlend: Double

    var isEnabled: Bool {
        hapticIntensity > 0
    }

    init(timeline: BreathingTimeline) {
        breathsPerMinute = timeline.breathsPerMinute
        peakHapticPulsesPerSecond = timeline.peakHapticPulsesPerSecond
        hapticIntensity = timeline.hapticIntensity
        hapticFrequency = timeline.hapticFrequency
        hapticCurveSmoothBlend = timeline.hapticCurveSmoothBlend
        hapticCurvePeakBlend = timeline.hapticCurvePeakBlend
        hapticCurveEarlyBlend = timeline.hapticCurveEarlyBlend
    }
}
#endif

enum HapticPulseEvent: Equatable {
    case inhaleStarted
    case inhaleEnded
    case pulse(intensity: Double)
}

struct HapticPulseScheduler {
    static let inhaleStartPulseIntensity = 0.82
    static let minimumPulseIntensity = 0.62
    static let maximumPulseIntensity = 1.0

    private(set) var isInhaling = false
    private var isHapticSessionActive = false
    private var lastUpdate: Date?
    private var pulseAccumulator = 0.0

    mutating func update(with snapshot: BreathingSnapshot, at date: Date) -> [HapticPulseEvent] {
        guard snapshot.isInhale else {
            lastUpdate = date

            guard isInhaling else {
                return []
            }

            isInhaling = false
            pulseAccumulator = 0

            guard isHapticSessionActive else {
                return []
            }

            isHapticSessionActive = false
            return [.inhaleEnded]
        }

        var events: [HapticPulseEvent] = []
        let hapticsEnabled = snapshot.hapticIntensityScale > 0

        if !isInhaling {
            isInhaling = true
            pulseAccumulator = 0

            if hapticsEnabled {
                isHapticSessionActive = true
                events.append(.inhaleStarted)
                events.append(.pulse(intensity: Self.inhaleStartPulseIntensity * snapshot.hapticIntensityScale))
            }
        }

        guard hapticsEnabled, snapshot.hapticPulsesPerSecond > 0 else {
            lastUpdate = date
            return events
        }

        let delta = max(0, min(0.1, date.timeIntervalSince(lastUpdate ?? date)))
        lastUpdate = date
        pulseAccumulator += delta * snapshot.hapticPulsesPerSecond

        let intensity = Self.minimumPulseIntensity
            + (Self.maximumPulseIntensity - Self.minimumPulseIntensity) * snapshot.hapticRate

        while pulseAccumulator >= 1 {
            pulseAccumulator -= 1
            events.append(.pulse(intensity: intensity * snapshot.hapticIntensityScale))
        }

        return events
    }

    mutating func stop() {
        lastUpdate = nil
        pulseAccumulator = 0
        isInhaling = false
        isHapticSessionActive = false
    }
}
