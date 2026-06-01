import SwiftUI

enum MeditationRenderer {
    private struct LightString {
        let path: Path
        let color: Color
        let glowWidth: CGFloat
        let coreWidth: CGFloat
        let glowOpacity: Double
        let coreOpacity: Double
    }

    static func drawSilkRibbon(
        in context: inout GraphicsContext,
        size: CGSize,
        snapshot: BreathingSnapshot,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let motionScale: CGFloat = reduceMotion ? 0.35 : 1
        let breath = CGFloat(snapshot.breathAmount) * motionScale
        let centerY = height * (0.55 - 0.018 * breath)
        let sampleCount = reduceMotion ? 42 : 66
        var strings: [LightString] = []

        for layer in 0..<9 {
            let i = CGFloat(layer)
            let seed = layer * 37 + 19
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 11)
            let n2 = pseudoNoise(seed + 23)
            let n3 = pseudoNoise(seed + 41)
            let phase = CGFloat(time) * (0.18 + 0.08 * n0) + i * 1.73
            let counterPhase = CGFloat(time) * (0.10 + 0.09 * n2) + i * 2.61
            let horizontalDrift = width * (
                0.16 * sin(phase * 0.68 + i)
                + 0.07 * sin(counterPhase + 1.7)
                + 0.035 * cos(CGFloat(time) * 0.045 + i * 3.4)
            )
            let baseOffset = (i - 4) * (height * 0.014 + 5 * n1) + (n2 - 0.5) * height * 0.12
            let amplitudeA = height * (0.080 + 0.045 * n1) * (0.76 + 0.34 * breath)
            let amplitudeB = height * (0.022 + 0.026 * n2)
            let amplitudeC = height * (0.010 + 0.014 * n3)
            var spine: [CGPoint] = []

            for sample in 0...sampleCount {
                let progress = CGFloat(sample) / CGFloat(sampleCount)
                let envelope = sin(progress * .pi)
                let flow = progress * 2 * .pi
                let xCurl = width * 0.040 * envelope * sin(flow * (1.1 + 0.28 * n3) - phase * 0.84 + i)
                let x = width * (-0.22 + 1.44 * progress) + horizontalDrift + xCurl
                let primary = sin(flow * (0.82 + 0.22 * n0) + phase)
                let secondary = sin(flow * (1.72 + 0.44 * n2) - counterPhase * 0.62 + i * 0.8)
                let tertiary = sin(flow * (3.20 + 0.34 * n3) + phase * 1.28 + i * 1.5)
                let inhaleCurl = (breath - 0.5) * height * 0.040 * envelope * sin(flow + i * 0.7)
                let y = centerY
                    + baseOffset
                    + envelope * amplitudeA * primary
                    + amplitudeB * secondary
                    + amplitudeC * tertiary
                    + inhaleCurl

                spine.append(CGPoint(x: x, y: y))
            }

            strings.append(
                LightString(
                    path: smoothPath(through: spine),
                    color: lightStringColor(index: layer, seed: n0, breath: breath),
                    glowWidth: 12 + 12 * n1 + 9 * breath,
                    coreWidth: 0.9 + 1.4 * n3,
                    glowOpacity: 0.16 + 0.09 * Double(breath) + 0.035 * Double(n2),
                    coreOpacity: 0.24 + 0.16 * Double(breath) + 0.05 * Double(n0)
                )
            )
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 12 + 8 * breath))

            for string in strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.glowOpacity)),
                    style: StrokeStyle(lineWidth: string.glowWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 2.5 + 2.5 * breath))

            for string in strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.coreOpacity * 0.50)),
                    style: StrokeStyle(lineWidth: string.coreWidth * 4.2, lineCap: .round, lineJoin: .round)
                )
            }
        }

        for string in strings {
            context.stroke(
                string.path,
                with: .color(string.color.opacity(string.coreOpacity)),
                style: StrokeStyle(lineWidth: string.coreWidth, lineCap: .round, lineJoin: .round)
            )
        }

        drawSoftParticles(
            in: &context,
            size: size,
            count: reduceMotion ? 10 : 22,
            centerY: centerY,
            breath: breath,
            time: time,
            color: Color(red: 0.74, green: 0.9, blue: 1.0)
        )
    }

    static func drawBreathingHorizon(
        in context: inout GraphicsContext,
        size: CGSize,
        snapshot: BreathingSnapshot,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let motionScale: CGFloat = reduceMotion ? 0.35 : 1
        let breath = CGFloat(snapshot.breathAmount) * motionScale
        let horizonY = height * 0.60
        let cameraWobble = CGFloat(sin(time * 0.17) * 1.4 + cos(time * 0.11) * 0.9) * motionScale
        let sunRadius = min(width, height) * 0.15
        let sunCenter = CGPoint(
            x: width * (0.5 + 0.012 * sin(CGFloat(time) * 0.08)),
            y: horizonY + cameraWobble + height * 0.05 - sunRadius * (0.52 + 0.80 * breath)
        )

        var sky = Path()
        sky.addRect(CGRect(x: 0, y: 0, width: width, height: horizonY))
        context.fill(
            sky,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.14 + 0.08 * Double(breath), green: 0.16, blue: 0.30),
                    Color(red: 0.35 + 0.14 * Double(breath), green: 0.23 + 0.09 * Double(breath), blue: 0.35),
                    Color(red: 0.95, green: 0.48 + 0.18 * Double(breath), blue: 0.38).opacity(0.72),
                ]),
                startPoint: CGPoint(x: width * 0.2, y: 0),
                endPoint: CGPoint(x: width * 0.58, y: horizonY)
            )
        )

        context.fill(
            Path(ellipseIn: CGRect(
                x: sunCenter.x - sunRadius * 4.2,
                y: sunCenter.y - sunRadius * 4.0,
                width: sunRadius * 8.4,
                height: sunRadius * 8.4
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.68, blue: 0.42).opacity(0.24 + 0.10 * Double(breath)),
                    Color(red: 0.92, green: 0.36, blue: 0.44).opacity(0.12 + 0.06 * Double(breath)),
                    .clear,
                ]),
                center: sunCenter,
                startRadius: sunRadius * 0.2,
                endRadius: sunRadius * 4.2
            )
        )

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 34))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: sunCenter.x - sunRadius * 2.4,
                    y: sunCenter.y - sunRadius * 2.2,
                    width: sunRadius * 4.8,
                    height: sunRadius * 4.8
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.74, blue: 0.45).opacity(0.58 + 0.18 * Double(breath)),
                        Color(red: 0.96, green: 0.32, blue: 0.38).opacity(0.20 + 0.10 * Double(breath)),
                        .clear,
                    ]),
                    center: sunCenter,
                    startRadius: 0,
                    endRadius: sunRadius * 2.4
                )
            )
        }

        context.fill(
            Path(ellipseIn: CGRect(
                x: sunCenter.x - sunRadius,
                y: sunCenter.y - sunRadius,
                width: sunRadius * 2,
                height: sunRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.88, blue: 0.62),
                    Color(red: 1.0, green: 0.52, blue: 0.43),
                ]),
                center: sunCenter,
                startRadius: 0,
                endRadius: sunRadius
            )
        )

        var water = Path()
        water.addRect(CGRect(x: 0, y: horizonY, width: width, height: height - horizonY))
        context.fill(
            water,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.10, green: 0.16 + 0.04 * Double(breath), blue: 0.25),
                    Color(red: 0.03, green: 0.055, blue: 0.10),
                ]),
                startPoint: CGPoint(x: width * 0.5, y: horizonY),
                endPoint: CGPoint(x: width * 0.5, y: height)
            )
        )

        drawReflection(in: &context, size: size, horizonY: horizonY, breath: breath, time: time, sunCenterX: sunCenter.x)

        var horizon = Path()
        for step in 0...28 {
            let x = width * CGFloat(step) / 28
            let wobble = CGFloat(
                sin(time * 0.24 + Double(step) * 0.58) * 1.8
                + sin(time * 0.13 + Double(step) * 0.31) * 0.9
            ) * motionScale
            let point = CGPoint(x: x, y: horizonY + wobble)

            if step == 0 {
                horizon.move(to: point)
            } else {
                horizon.addLine(to: point)
            }
        }
        context.stroke(
            horizon,
            with: .color(Color.white.opacity(0.34 + Double(breath) * 0.10)),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
        )
    }

    static func drawInkBloom(
        in context: inout GraphicsContext,
        size: CGSize,
        snapshot: BreathingSnapshot,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let motionScale: CGFloat = reduceMotion ? 0.35 : 1
        let breath = CGFloat(snapshot.breathAmount) * motionScale
        let fullBreath = CGFloat(snapshot.breathAmount)
        let t = CGFloat(time)
        let center = CGPoint(
            x: width * (0.51 + 0.018 * sin(t * 0.10)),
            y: height * (0.47 + 0.025 * cos(t * 0.07))
        )
        let scale = min(width, height)
        let reach = scale * (0.30 + 0.32 * breath)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 22))

            for index in 0..<(reduceMotion ? 5 : 12) {
                let i = CGFloat(index)
                let n0 = pseudoNoise(index + 3)
                let n1 = pseudoNoise(index + 17)
                let n2 = pseudoNoise(index + 31)
                let localPulseSpeed = 0.08 + 0.08 * n1
                let localPulse = 0.5 + 0.5 * sin(t * localPulseSpeed + i * 2.31 + n2 * 6.28)
                let localBreath = min(1, max(0, 0.56 * fullBreath + 0.44 * localPulse))
                let angle = i * 2.399_963
                    + t * (0.016 + 0.030 * n0)
                    + CGFloat(localPulse) * 0.36
                let distance = reach * (0.12 + 0.48 * n0) * (0.78 + 0.34 * localBreath)
                let driftXSpeed = 0.07 + 0.06 * n0
                let driftYSpeed = 0.06 + 0.05 * n2
                let drift = CGPoint(
                    x: scale * (0.018 + 0.030 * n2) * sin(t * driftXSpeed + i * 1.7),
                    y: scale * (0.016 + 0.026 * n1) * cos(t * driftYSpeed + i * 1.2)
                )
                let cloudCenter = CGPoint(
                    x: center.x + cos(angle) * distance * 1.20 + drift.x,
                    y: center.y + sin(angle) * distance * 0.82 + drift.y
                )
                let radius = scale * (0.18 + 0.15 * n1) * (0.88 + 0.34 * localBreath)
                let rect = CGRect(
                    x: cloudCenter.x - radius * (1.05 + n0),
                    y: cloudCenter.y - radius * (0.88 + 0.45 * n1),
                    width: radius * (1.9 + 1.2 * n0),
                    height: radius * (1.6 + 1.0 * n1)
                )
                let colors: [Color] = [
                    Color(red: 0.78, green: 0.66, blue: 1.0).opacity(0.19 + 0.11 * Double(localBreath)),
                    Color(red: 0.20, green: 0.63, blue: 1.0).opacity(0.13 + 0.10 * Double(localPulse)),
                    Color(red: 0.36, green: 0.18, blue: 0.78).opacity(0.08),
                    .clear,
                ]

                fillRadialEllipse(
                    in: &layer,
                    rect: rect,
                    center: cloudCenter,
                    startRadius: 0,
                    endRadius: radius * 1.8,
                    colors: colors
                )
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 7 + 6 * (1 - breath)))

            for index in 0..<(reduceMotion ? 14 : 38) {
                let i = CGFloat(index)
                let n0 = pseudoNoise(index)
                let n1 = pseudoNoise(index + 19)
                let n2 = pseudoNoise(index + 37)
                let n3 = pseudoNoise(index + 53)
                let localPulseSpeed = 0.11 + 0.18 * n2
                let counterPulseSpeed = 0.07 + 0.13 * n3
                let localPulse = 0.5 + 0.5 * sin(t * localPulseSpeed + i * 1.71 + n1 * 4.4)
                let counterPulse = 0.5 + 0.5 * cos(t * counterPulseSpeed + i * 0.97 + n0 * 5.2)
                let localBreath = min(1, max(0, 0.50 * fullBreath + 0.30 * localPulse + 0.20 * counterPulse))
                let angle = i * 2.399_963
                    + t * (0.012 + 0.028 * n1)
                    + CGFloat(counterPulse - 0.5) * 0.44
                let distance = reach * (0.12 + 0.86 * n0) * (0.76 + 0.34 * localPulse + 0.20 * localBreath)
                let driftXSpeed = 0.10 + 0.12 * n2
                let driftYSpeed = 0.08 + 0.11 * n1
                let drift = CGPoint(
                    x: scale * (0.012 + 0.026 * n3) * sin(t * driftXSpeed + i * 2.4),
                    y: scale * (0.012 + 0.024 * n2) * cos(t * driftYSpeed + i * 1.8)
                )
                let asymmetry = CGSize(
                    width: cos(angle) * distance * (1.20 + 0.34 * sin(i * 0.61 + counterPulse)),
                    height: sin(angle) * distance * (0.76 + 0.36 * cos(i * 0.7 + localPulse))
                )
                let particleCenter = CGPoint(
                    x: center.x + asymmetry.width + drift.x,
                    y: center.y + asymmetry.height + drift.y
                )
                let radius = scale * (0.046 + 0.094 * n1) * (0.84 + 0.54 * localBreath)
                let alpha = 0.13 + 0.16 * Double(localPulse) + 0.12 * Double(localBreath)
                let rect = CGRect(
                    x: particleCenter.x - radius * (0.8 + n2),
                    y: particleCenter.y - radius * (0.8 + 0.8 * n3),
                    width: radius * (1.3 + 1.6 * n2),
                    height: radius * (1.2 + 1.7 * n3)
                )
                let colors: [Color] = [
                    Color.white.opacity(alpha * 0.34),
                    Color(red: 0.82, green: 0.62, blue: 1.0).opacity(alpha * 1.05),
                    Color(red: 0.18, green: 0.70, blue: 1.0).opacity(alpha * 0.72),
                    Color(red: 0.42, green: 0.18, blue: 0.86).opacity(alpha * 0.48),
                    .clear,
                ]

                fillRadialEllipse(
                    in: &layer,
                    rect: rect,
                    center: particleCenter,
                    startRadius: radius * 0.04,
                    endRadius: radius * 1.9,
                    colors: colors
                )
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - reach * 0.58,
                    y: center.y - reach * 0.48,
                    width: reach * 1.16,
                    height: reach * 0.96
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.18 + 0.12 * Double(fullBreath)),
                        Color(red: 0.64, green: 0.55, blue: 1.0).opacity(0.26 + 0.14 * Double(breath)),
                        Color(red: 0.16, green: 0.72, blue: 1.0).opacity(0.17),
                        .clear,
                    ]),
                    center: center,
                    startRadius: reach * 0.08,
                    endRadius: reach * 0.64
                )
            )
        }
    }

    private static func drawReflection(
        in context: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        breath: CGFloat,
        time: TimeInterval,
        sunCenterX: CGFloat
    ) {
        let width = size.width
        let height = size.height

        for index in 0..<12 {
            let i = CGFloat(index)
            let y = horizonY + 22 + i * (height - horizonY) / 15
            let halfWidth = width * (0.10 + 0.028 * i) * (0.75 + 0.35 * breath)
            let wave = sin(CGFloat(time) * 0.45 + i * 0.82) * 10

            var path = Path()
            path.move(to: CGPoint(x: sunCenterX - halfWidth, y: y + wave))
            path.addCurve(
                to: CGPoint(x: sunCenterX + halfWidth, y: y - wave * 0.3),
                control1: CGPoint(x: sunCenterX - halfWidth * 0.35, y: y - 8 - wave),
                control2: CGPoint(x: sunCenterX + halfWidth * 0.35, y: y + 8 + wave)
            )

            context.stroke(
                path,
                with: .color(Color(red: 1.0, green: 0.68, blue: 0.42).opacity((0.16 + 0.17 * Double(breath)) / Double(index + 1))),
                style: StrokeStyle(lineWidth: 1.2 + breath * 1.8, lineCap: .round)
            )
        }
    }

    private static func drawSoftParticles(
        in context: inout GraphicsContext,
        size: CGSize,
        count: Int,
        centerY: CGFloat,
        breath: CGFloat,
        time: TimeInterval,
        color: Color
    ) {
        let width = size.width
        let height = size.height

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 4 + 4 * breath))

            for index in 0..<count {
                let noise = pseudoNoise(index)
                let phase = CGFloat(time) * (0.18 + 0.10 * pseudoNoise(index + 8)) + CGFloat(index) * 1.7
                let x = width * CGFloat(noise) + width * 0.025 * sin(phase * 0.7)
                let y = centerY + sin(phase) * (height * 0.035 + 34 * breath)
                let radius = CGFloat(5.0 + 12.0 * pseudoNoise(index + 13)) * (0.85 + 0.45 * breath)
                let opacity = 0.055 + 0.10 * Double(breath) * Double(0.35 + pseudoNoise(index + 5))

                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: x - radius * (1.2 + pseudoNoise(index + 21)),
                        y: y - radius * (0.9 + 0.6 * pseudoNoise(index + 34)),
                        width: radius * (2.0 + 1.0 * pseudoNoise(index + 55)),
                        height: radius * (1.8 + 1.1 * pseudoNoise(index + 89))
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            color.opacity(opacity),
                            Color.white.opacity(opacity * 0.34),
                            .clear,
                        ]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: radius * 1.9
                    )
                )
            }
        }
    }

    private static func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else {
            return path
        }

        path.move(to: first)

        guard points.count > 2 else {
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            return path
        }

        let lastIndex = points.count - 1

        for index in 0..<lastIndex {
            let p0 = points[max(0, index - 1)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(lastIndex, index + 2)]
            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )

            path.addCurve(to: p2, control1: control1, control2: control2)
        }

        return path
    }

    private static func fillRadialEllipse(
        in context: inout GraphicsContext,
        rect: CGRect,
        center: CGPoint,
        startRadius: CGFloat,
        endRadius: CGFloat,
        colors: [Color]
    ) {
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: colors),
                center: center,
                startRadius: startRadius,
                endRadius: endRadius
            )
        )
    }

    private static func lightStringColor(index: Int, seed: CGFloat, breath: CGFloat) -> Color {
        let palette = index % 4
        let warmth = Double(breath) * 0.20
        let jitter = Double(seed - 0.5) * 0.06

        switch palette {
        case 0:
            return Color(red: 0.58 + warmth + jitter, green: 0.84 + warmth * 0.35, blue: 1.0)
        case 1:
            return Color(red: 0.76 + warmth * 0.65, green: 0.68 + warmth * 0.42 + jitter, blue: 1.0)
        case 2:
            return Color(red: 1.0, green: 0.74 + warmth * 0.30 + jitter, blue: 0.62 + warmth * 0.45)
        default:
            return Color(red: 0.62 + warmth * 0.38, green: 1.0, blue: 0.92 + jitter)
        }
    }

    private static func pseudoNoise(_ seed: Int) -> CGFloat {
        let value = sin(Double(seed) * 12.9898) * 43_758.5453
        return CGFloat(value - floor(value))
    }
}
