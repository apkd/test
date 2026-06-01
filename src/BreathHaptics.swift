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
                playSoftPulse(intensity: intensity)
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
        generator = UIImpactFeedbackGenerator(style: .soft)
        generator?.prepare()
        #endif
    }

    private func endInhale() {
        #if os(iOS)
        generator = nil
        #endif
    }

    private func playSoftPulse(intensity: Double) {
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
        events.append(.pulse(intensity: 0.16 + 0.22 * snapshot.hapticRate))
        return events
    }

    mutating func stop() {
        lastUpdate = nil
        pulseAccumulator = 0
        isInhaling = false
    }
}
