import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

@MainActor
final class BreathHapticCoordinator: ObservableObject {
    private var scheduler = HapticPulseScheduler()

    #if os(iOS)
    private var generator: UIImpactFeedbackGenerator?
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
        #endif
    }

    private func beginInhale() {
        #if os(iOS)
        generator = UIImpactFeedbackGenerator(style: .medium)
        generator?.prepare()
        #endif
    }

    private func endInhale() {
        #if os(iOS)
        generator = nil
        #endif
    }

    private func playPulse(intensity: Double) {
        #if os(iOS)
        generator?.impactOccurred(intensity: CGFloat(max(0, min(1, intensity))))
        generator?.prepare()
        #endif
    }
}

enum HapticPulseEvent: Equatable {
    case inhaleStarted
    case inhaleEnded
    case pulse(intensity: Double)
}

struct HapticPulseScheduler {
    static let inhaleStartPulseIntensity = 0.72
    static let minimumPulseIntensity = 0.55
    static let maximumPulseIntensity = 1.0

    private(set) var isInhaling = false
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
            return [.inhaleEnded]
        }

        var events: [HapticPulseEvent] = []

        if !isInhaling {
            isInhaling = true
            pulseAccumulator = 0
            events.append(.inhaleStarted)
            events.append(.pulse(intensity: Self.inhaleStartPulseIntensity))
        }

        guard snapshot.hapticPulsesPerSecond > 0 else {
            lastUpdate = date
            return events
        }

        let delta = max(0, min(0.1, date.timeIntervalSince(lastUpdate ?? date)))
        lastUpdate = date
        pulseAccumulator += delta * snapshot.hapticPulsesPerSecond

        guard pulseAccumulator >= 1 else {
            return events
        }

        pulseAccumulator.formTruncatingRemainder(dividingBy: 1)
        let intensity = Self.minimumPulseIntensity
            + (Self.maximumPulseIntensity - Self.minimumPulseIntensity) * snapshot.hapticRate
        events.append(.pulse(intensity: intensity))
        return events
    }

    mutating func stop() {
        lastUpdate = nil
        pulseAccumulator = 0
        isInhaling = false
    }
}
