import Foundation
import SwiftUI

enum MeditationAnimationMode: Int, CaseIterable, Identifiable {
    case silkRibbon
    case breathingHorizon
    case inkBloom

    static let defaultMode: MeditationAnimationMode = .breathingHorizon

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .silkRibbon:
            "Silk ribbon"
        case .breathingHorizon:
            "Breathing horizon"
        case .inkBloom:
            "Ink bloom"
        }
    }

    var shortTitle: String {
        switch self {
        case .silkRibbon:
            "Silk"
        case .breathingHorizon:
            "Horizon"
        case .inkBloom:
            "Bloom"
        }
    }

    var instruction: String {
        switch self {
        case .silkRibbon:
            "Follow the ribbon as it gathers and releases."
        case .breathingHorizon:
            "Let the horizon lift, then settle."
        case .inkBloom:
            "Watch the breath diffuse through quiet water."
        }
    }

    var accent: Color {
        switch self {
        case .silkRibbon:
            Color(red: 0.76, green: 0.87, blue: 1.0)
        case .breathingHorizon:
            Color(red: 1.0, green: 0.74, blue: 0.49)
        case .inkBloom:
            Color(red: 0.72, green: 0.56, blue: 1.0)
        }
    }

    var next: MeditationAnimationMode {
        MeditationAnimationMode(rawValue: (rawValue + 1) % Self.allCases.count) ?? .silkRibbon
    }

    var previous: MeditationAnimationMode {
        MeditationAnimationMode(rawValue: (rawValue + Self.allCases.count - 1) % Self.allCases.count) ?? .inkBloom
    }
}

enum BreathPhase: Equatable {
    case inhale
    case exhale

    var title: String {
        switch self {
        case .inhale:
            "Breathe in"
        case .exhale:
            "Breathe out"
        }
    }
}

struct BreathingSnapshot: Equatable {
    let elapsed: TimeInterval
    let cycleProgress: Double
    let phaseProgress: Double
    let angle: Double
    let sine: Double
    let phase: BreathPhase
    let breathAmount: Double
    let hapticRate: Double
    let hapticPulsesPerSecond: Double

    var isInhale: Bool { phase == .inhale }
}

struct BreathingTimeline {
    static let initialElapsedOffset: TimeInterval = 0.35

    var breathsPerMinute: Double = 7
    var peakHapticPulsesPerSecond: Double = 1.7

    var cycleDuration: TimeInterval {
        60 / breathsPerMinute
    }

    func snapshot(at date: Date, startedAt: Date) -> BreathingSnapshot {
        snapshot(elapsed: date.timeIntervalSince(startedAt))
    }

    func snapshot(elapsed: TimeInterval) -> BreathingSnapshot {
        let safeElapsed = max(0, elapsed)
        let cycleProgress = (safeElapsed / cycleDuration).truncatingRemainder(dividingBy: 1)
        let angle = cycleProgress * 2 * Double.pi
        let sine = sin(angle)
        let isInhale = cycleProgress < 0.5
        let phaseProgress = isInhale ? cycleProgress * 2 : (cycleProgress - 0.5) * 2
        let easedPhaseProgress = Self.smoothstep(max(0, min(1, phaseProgress)))
        let breathAmount = isInhale ? easedPhaseProgress : 1 - easedPhaseProgress
        let hapticRate = isInhale ? max(0, sine) : 0
        let hapticPulsesPerSecond = peakHapticPulsesPerSecond * hapticRate

        return BreathingSnapshot(
            elapsed: safeElapsed,
            cycleProgress: cycleProgress,
            phaseProgress: max(0, min(1, phaseProgress)),
            angle: angle,
            sine: sine,
            phase: isInhale ? .inhale : .exhale,
            breathAmount: breathAmount,
            hapticRate: hapticRate,
            hapticPulsesPerSecond: hapticPulsesPerSecond
        )
    }

    static func smoothstep(_ value: Double) -> Double {
        let clamped = max(0, min(1, value))
        return clamped * clamped * (3 - 2 * clamped)
    }
}
