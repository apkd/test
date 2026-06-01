import Foundation
import SwiftUI

enum MeditationAnimationMode: Int, CaseIterable, Identifiable {
    case silkRibbon
    case breathingHorizon
    case inkBloom

    static let defaultMode: MeditationAnimationMode = .breathingHorizon
    static let launchEnvironmentKey = "MEDITATION_ANIMATION_MODE"

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

    var launchValue: String {
        switch self {
        case .silkRibbon:
            "silk-ribbon"
        case .breathingHorizon:
            "breathing-horizon"
        case .inkBloom:
            "ink-bloom"
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

    static func launchMode(environment: [String: String] = ProcessInfo.processInfo.environment) -> MeditationAnimationMode {
        guard let rawValue = environment[launchEnvironmentKey]?.lowercased() else {
            return defaultMode
        }

        return allCases.first { mode in
            rawValue == mode.launchValue || rawValue == mode.shortTitle.lowercased()
        } ?? defaultMode
    }
}

enum MeditationPanel: Int, CaseIterable, Identifiable {
    case configuration
    case breathingHorizon
    case silkRibbon
    case inkBloom

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .configuration:
            "Configuration"
        case .breathingHorizon:
            MeditationAnimationMode.breathingHorizon.title
        case .silkRibbon:
            MeditationAnimationMode.silkRibbon.title
        case .inkBloom:
            MeditationAnimationMode.inkBloom.title
        }
    }

    var shortTitle: String {
        switch self {
        case .configuration:
            "Config"
        case .breathingHorizon:
            MeditationAnimationMode.breathingHorizon.shortTitle
        case .silkRibbon:
            MeditationAnimationMode.silkRibbon.shortTitle
        case .inkBloom:
            MeditationAnimationMode.inkBloom.shortTitle
        }
    }

    var animationMode: MeditationAnimationMode? {
        switch self {
        case .configuration:
            nil
        case .breathingHorizon:
            .breathingHorizon
        case .silkRibbon:
            .silkRibbon
        case .inkBloom:
            .inkBloom
        }
    }

    var accent: Color {
        animationMode?.accent ?? Color(red: 0.80, green: 0.86, blue: 1.0)
    }

    var next: MeditationPanel? {
        MeditationPanel(rawValue: rawValue + 1)
    }

    var previous: MeditationPanel? {
        MeditationPanel(rawValue: rawValue - 1)
    }

    static func panel(for mode: MeditationAnimationMode) -> MeditationPanel {
        switch mode {
        case .silkRibbon:
            .silkRibbon
        case .breathingHorizon:
            .breathingHorizon
        case .inkBloom:
            .inkBloom
        }
    }

    static func launchPanel(environment: [String: String] = ProcessInfo.processInfo.environment) -> MeditationPanel {
        launchOverride(environment: environment) ?? panel(for: MeditationAnimationMode.launchMode(environment: environment))
    }

    static func launchOverride(environment: [String: String] = ProcessInfo.processInfo.environment) -> MeditationPanel? {
        guard let rawValue = environment[MeditationAnimationMode.launchEnvironmentKey]?.lowercased() else {
            return nil
        }

        if rawValue == "configuration" || rawValue == "config" {
            return .configuration
        }

        return allCases.first { panel in
            panel.animationMode.map { rawValue == $0.launchValue || rawValue == $0.shortTitle.lowercased() } ?? false
        }
    }
}

enum MeditationPersistenceKey {
    static let panelRawValue = "meditation.panel.rawValue"
    static let lastAnimationModeRawValue = "meditation.lastAnimationMode.rawValue"
    static let breathsPerMinute = "meditation.breathsPerMinute"
    static let hapticIntensity = "meditation.hapticIntensity"
    static let hapticFrequency = "meditation.hapticFrequency"
    static let hapticCurveTiming = "meditation.hapticCurve.timing"
    static let hapticCurveFocus = "meditation.hapticCurve.focus"
    static let hapticCurveFloor = "meditation.hapticCurve.floor"
}

struct MeditationSettings: Equatable {
    static let defaultBreathsPerMinute = 7.0
    static let defaultHapticIntensity = 0.5
    static let defaultHapticFrequency = 0.5
    static let defaultHapticCurveTiming = 0.0
    static let defaultHapticCurveFocus = 0.0
    static let defaultHapticCurveFloor = 0.0
    static let breathsPerMinuteRange: ClosedRange<Double> = 4...12
    static let hapticIntensityRange: ClosedRange<Double> = 0...1
    static let hapticFrequencyRange: ClosedRange<Double> = 0...1
    static let hapticCurveTimingRange: ClosedRange<Double> = -1...1
    static let hapticCurveControlRange: ClosedRange<Double> = 0...1

    var breathsPerMinute: Double = defaultBreathsPerMinute
    var hapticIntensity: Double = defaultHapticIntensity
    var hapticFrequency: Double = defaultHapticFrequency
    var hapticCurveTiming: Double = defaultHapticCurveTiming
    var hapticCurveFocus: Double = defaultHapticCurveFocus
    var hapticCurveFloor: Double = defaultHapticCurveFloor

    var timeline: BreathingTimeline {
        BreathingTimeline(
            breathsPerMinute: breathsPerMinute,
            hapticIntensity: hapticIntensity,
            hapticFrequency: hapticFrequency,
            hapticCurveTiming: hapticCurveTiming,
            hapticCurveFocus: hapticCurveFocus,
            hapticCurveFloor: hapticCurveFloor
        )
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
    let hapticIntensity: Double
    let hapticIntensityScale: Double
    let hapticFrequency: Double
    let hapticPulsesPerSecond: Double

    var isInhale: Bool { phase == .inhale }
}

struct BreathingTimeline {
    static let initialElapsedOffset: TimeInterval = 0.35
    static let hapticCurveMaximumShift = 0.32
    static let hapticCurveMaximumFloor = 0.65

    var breathsPerMinute: Double = 7
    var peakHapticPulsesPerSecond: Double = 40.0
    var hapticIntensity: Double = MeditationSettings.defaultHapticIntensity
    var hapticFrequency: Double = MeditationSettings.defaultHapticFrequency
    var hapticCurveTiming: Double = MeditationSettings.defaultHapticCurveTiming
    var hapticCurveFocus: Double = MeditationSettings.defaultHapticCurveFocus
    var hapticCurveFloor: Double = MeditationSettings.defaultHapticCurveFloor

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
        let baseHapticRate = isInhale ? max(0, sine) : 0
        let hapticRate = isInhale
            ? Self.shapedHapticRate(
                phaseProgress: phaseProgress,
                baseRate: baseHapticRate,
                timing: hapticCurveTiming,
                focus: hapticCurveFocus,
                floor: hapticCurveFloor
            )
            : 0
        let clampedHapticIntensity = max(0, min(1, hapticIntensity))
        let clampedHapticFrequency = max(0, min(1, hapticFrequency))
        let hapticIntensityScale = clampedHapticIntensity * 2
        let hapticPulsesPerSecond = clampedHapticIntensity > 0
            ? peakHapticPulsesPerSecond * clampedHapticFrequency * hapticRate
            : 0

        return BreathingSnapshot(
            elapsed: safeElapsed,
            cycleProgress: cycleProgress,
            phaseProgress: max(0, min(1, phaseProgress)),
            angle: angle,
            sine: sine,
            phase: isInhale ? .inhale : .exhale,
            breathAmount: breathAmount,
            hapticRate: hapticRate,
            hapticIntensity: clampedHapticIntensity,
            hapticIntensityScale: hapticIntensityScale,
            hapticFrequency: clampedHapticFrequency,
            hapticPulsesPerSecond: hapticPulsesPerSecond
        )
    }

    static func smoothstep(_ value: Double) -> Double {
        let clamped = max(0, min(1, value))
        return clamped * clamped * (3 - 2 * clamped)
    }

    static func shapedHapticRate(
        phaseProgress: Double,
        baseRate: Double,
        timing: Double,
        focus: Double,
        floor: Double
    ) -> Double {
        let phase = max(0, min(1, phaseProgress))
        let base = max(0, min(1, baseRate))
        let clampedTiming = max(-1, min(1, timing))
        let clampedFocus = max(0, min(1, focus))
        let clampedFloor = max(0, min(1, floor))
        let center = 0.5 + hapticCurveMaximumShift * clampedTiming
        let width = 0.50 - 0.34 * clampedFocus
        let normalizedDistance = (phase - center) / width
        let shiftedPeak = exp(-1.8 * normalizedDistance * normalizedDistance)
        let shapedBlend = min(1, abs(clampedTiming) + clampedFocus)
        let focusedRate = base * (1 - shapedBlend) + shiftedPeak * shapedBlend
        let floorRate = hapticCurveMaximumFloor * clampedFloor

        return min(1, max(0, floorRate + (1 - floorRate) * focusedRate))
    }
}
