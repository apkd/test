import SwiftUI

struct ConfigurationPanel: View {
    @Binding var breathsPerMinute: Double
    @Binding var hapticIntensity: Double
    @Binding var hapticFrequency: Double
    @Binding var hapticCurveTiming: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Configuration", systemImage: "slider.horizontal.3")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))

            ConfigurationSlider(
                title: "Breathing speed",
                valueText: String(format: "%.1f bpm", breathsPerMinute),
                systemImage: "wind",
                value: $breathsPerMinute,
                range: MeditationSettings.breathsPerMinuteRange,
                step: 0.5,
                accent: Color(red: 1.0, green: 0.74, blue: 0.49)
            )

            ConfigurationSlider(
                title: "Haptics intensity",
                valueText: "\(Int((hapticIntensity * 100).rounded()))%",
                systemImage: "waveform.path",
                value: $hapticIntensity,
                range: MeditationSettings.hapticIntensityRange,
                step: 0.05,
                accent: Color(red: 0.72, green: 0.56, blue: 1.0)
            )

            ConfigurationSlider(
                title: "Haptics frequency",
                valueText: "\(Int((hapticFrequency * 100).rounded()))%",
                systemImage: "dot.radiowaves.left.and.right",
                value: $hapticFrequency,
                range: MeditationSettings.hapticFrequencyRange,
                step: 0.05,
                accent: Color(red: 0.56, green: 0.86, blue: 1.0)
            )

            ConfigurationSlider(
                title: "Pulse timing",
                valueText: timingText,
                systemImage: "arrow.left.and.right",
                value: $hapticCurveTiming,
                range: MeditationSettings.hapticCurveTimingRange,
                step: 0.05,
                accent: Color(red: 0.80, green: 0.92, blue: 1.0)
            )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: 380, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 18)
        .accessibilityElement(children: .contain)
    }

    private var timingText: String {
        let percent = Int((abs(hapticCurveTiming) * 100).rounded())

        if percent == 0 {
            return "Centered"
        }

        return hapticCurveTiming < 0 ? "Early \(percent)%" : "Late \(percent)%"
    }
}

struct ConfigButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.18), in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open configuration")
    }
}

private struct ConfigurationSlider: View {
    let title: String
    let valueText: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24)

                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer()

                Text(valueText)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Slider(value: $value, in: range, step: step)
                .tint(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }
}
