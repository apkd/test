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
    #endif

    func update(with snapshot: BreathingSnapshot, at date: Date) {
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
                    }
                }
                engine.resetHandler = { [weak self] in
                    Task { @MainActor in
                        _ = self?.ensureCoreHapticsStarted()
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
