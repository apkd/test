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
        let breath = CGFloat(snapshot.breathAmount)
        let phaseEase = CGFloat(BreathingTimeline.smoothstep(snapshot.phaseProgress))
        let inhaleDrive = snapshot.isInhale ? phaseEase : 0
        let energy = (snapshot.isInhale ? 0.45 + 0.95 * inhaleDrive : 0.15 + 0.26 * breath) * motionScale
        let spread = 0.44 + 0.82 * breath * motionScale
        let centerY = height * (0.55 - 0.010 * breath * motionScale)
        let sampleCount = reduceMotion ? 44 : 70
        let stringCount = reduceMotion ? 7 : 11
        var strings: [LightString] = []

        for layer in 0..<stringCount {
            let i = CGFloat(layer)
            let seed = layer * 37 + 19
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 11)
            let n2 = pseudoNoise(seed + 23)
            let n3 = pseudoNoise(seed + 41)
            let phase = CGFloat(time) * (0.08 + 0.44 * energy + 0.06 * n0) + i * 1.73
            let counterPhase = CGFloat(time) * (0.035 + 0.18 * energy + 0.04 * n2) + i * 2.61
            let horizontalDrift = width * (
                (0.045 + 0.13 * spread) * sin(phase * 0.56 + i)
                + (0.024 + 0.052 * energy) * sin(counterPhase + 1.7)
                + 0.018 * cos(CGFloat(time) * 0.040 + i * 3.4)
            )
            let baseOffset = (i - CGFloat(stringCount - 1) * 0.5) * (height * (0.010 + 0.014 * spread) + 4 * n1)
                + (n2 - 0.5) * height * 0.085 * spread
            let amplitudeA = height * (0.038 + 0.070 * n1) * spread
            let amplitudeB = height * (0.012 + 0.035 * n2) * (0.70 + 0.72 * energy)
            let amplitudeC = height * (0.006 + 0.017 * n3) * (0.45 + 0.88 * energy)
            var spine: [CGPoint] = []

            for sample in 0...sampleCount {
                let progress = CGFloat(sample) / CGFloat(sampleCount)
                let envelope = sin(progress * .pi)
                let flow = progress * 2 * .pi
                let xCurl = width * (0.014 + 0.052 * energy) * envelope * sin(flow * (1.1 + 0.28 * n3) - phase * 0.80 + i)
                let x = width * (-0.22 + 1.44 * progress) + horizontalDrift + xCurl
                let primary = sin(flow * (0.82 + 0.22 * n0) + phase)
                let secondary = sin(flow * (1.72 + 0.44 * n2) - counterPhase * 0.62 + i * 0.8)
                let tertiary = sin(flow * (3.20 + 0.34 * n3) + phase * 1.28 + i * 1.5)
                let inhaleCurl = inhaleDrive * height * 0.042 * envelope * sin(flow + phase * 0.36 + i * 0.7)
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
                    glowWidth: 18 + 18 * n1 + 12 * spread,
                    coreWidth: 0.45 + 0.78 * n3,
                    glowOpacity: 0.12 + 0.07 * Double(breath) + 0.055 * Double(energy) + 0.030 * Double(n2),
                    coreOpacity: 0.08 + 0.06 * Double(breath) + 0.075 * Double(energy) + 0.018 * Double(n0)
                )
            )
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 18 + 9 * breath))

            for string in strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.glowOpacity)),
                    style: StrokeStyle(lineWidth: string.glowWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 5.5 + 3.0 * breath))

            for string in strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.coreOpacity * 0.62)),
                    style: StrokeStyle(lineWidth: string.coreWidth * 6.5, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 1.4))

            for string in strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.coreOpacity * 0.56)),
                    style: StrokeStyle(lineWidth: string.coreWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }

        drawSoftParticles(
            in: &context,
            size: size,
            count: reduceMotion ? 14 : 42,
            centerY: centerY,
            breath: breath,
            energy: energy,
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
        let baseSunRadius = min(width, height) * 0.15
        let sunRadius = baseSunRadius * (0.975 + 0.05 * breath)
        let sunCenter = CGPoint(
            x: width * (0.5 + 0.012 * sin(CGFloat(time) * 0.08)),
            y: horizonY + cameraWobble + height * 0.05 - baseSunRadius * (0.52 + 0.64 * breath)
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

        drawOceanSurface(in: &context, size: size, horizonY: horizonY, breath: breath, time: time, sunCenterX: sunCenter.x)
        drawReflection(in: &context, size: size, horizonY: horizonY, breath: breath, time: time, sunCenterX: sunCenter.x)
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

    static func drawSoftGlow(
        in context: inout GraphicsContext,
        size: CGSize,
        snapshot: BreathingSnapshot,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let scale = min(width, height)
        let motionScale: CGFloat = reduceMotion ? 0.30 : 1
        let breath = CGFloat(snapshot.breathAmount) * motionScale
        let t = CGFloat(time)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 82))
            fillRadialEllipse(
                in: &layer,
                rect: CGRect(
                    x: width * 0.04,
                    y: height * 0.08,
                    width: width * 0.92,
                    height: height * 0.74
                ),
                center: CGPoint(
                    x: width * (0.50 + 0.018 * sin(t * 0.055)),
                    y: height * (0.42 + 0.022 * cos(t * 0.047))
                ),
                startRadius: scale * 0.08,
                endRadius: scale * (0.48 + 0.10 * breath),
                colors: [
                    Color(red: 0.38, green: 0.48, blue: 0.90).opacity(0.13 + 0.05 * Double(breath)),
                    Color(red: 0.18, green: 0.24, blue: 0.52).opacity(0.08 + 0.03 * Double(breath)),
                    .clear,
                ]
            )
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 34))

            for index in 0..<(reduceMotion ? 3 : 6) {
                let i = CGFloat(index)
                let n0 = pseudoNoise(index * 41 + 9)
                let n1 = pseudoNoise(index * 41 + 23)
                let n2 = pseudoNoise(index * 41 + 47)
                let localPulse = 0.5 + 0.5 * sin(t * (0.055 + 0.045 * n0) + i * 1.83)
                let drift = CGPoint(
                    x: width * (0.018 + 0.030 * n1) * sin(t * (0.034 + 0.035 * n2) + i * 2.2),
                    y: height * (0.014 + 0.024 * n0) * cos(t * (0.030 + 0.032 * n1) + i * 1.7)
                )
                let center = CGPoint(
                    x: width * (0.20 + 0.62 * n0) + drift.x,
                    y: height * (0.24 + 0.46 * n1) + drift.y
                )
                let radius = scale * (0.13 + 0.16 * n2) * (0.92 + 0.18 * breath + 0.10 * localPulse)
                let rect = CGRect(
                    x: center.x - radius * (1.20 + 0.40 * n1),
                    y: center.y - radius * (1.00 + 0.34 * n2),
                    width: radius * (2.20 + 0.80 * n1),
                    height: radius * (1.80 + 0.70 * n2)
                )
                let cool = Color(red: 0.54, green: 0.66, blue: 1.0)
                let violet = Color(red: 0.42, green: 0.32, blue: 0.78)
                let opacity = 0.035 + 0.034 * Double(localPulse) + 0.030 * Double(breath)

                fillRadialEllipse(
                    in: &layer,
                    rect: rect,
                    center: center,
                    startRadius: radius * 0.02,
                    endRadius: radius * 1.75,
                    colors: [
                        cool.opacity(opacity),
                        violet.opacity(opacity * 0.58),
                        .clear,
                    ]
                )
            }
        }

        drawSubtleNoise(in: &context, size: size, count: reduceMotion ? 220 : 520, alphaScale: reduceMotion ? 0.9 : 1.18)
    }

    private static func drawSubtleNoise(
        in context: inout GraphicsContext,
        size: CGSize,
        count: Int,
        alphaScale: Double
    ) {
        for index in 0..<count {
            let n0 = pseudoNoise(index * 73 + 17)
            let n1 = pseudoNoise(index * 73 + 31)
            let n2 = pseudoNoise(index * 73 + 59)
            let radius = 0.34 + 0.92 * n2
            let alpha = (0.0065 + 0.0125 * Double(pseudoNoise(index * 73 + 83))) * alphaScale
            let color = index.isMultiple(of: 2)
                ? Color.white.opacity(alpha)
                : Color.black.opacity(alpha * 0.65)

            context.fill(
                Path(ellipseIn: CGRect(x: size.width * n0, y: size.height * n1, width: radius, height: radius)),
                with: .color(color)
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
        let waterHeight = max(1, height - horizonY)
        let t = CGFloat(time)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.55))

            for index in 0..<54 {
                let i = CGFloat(index)
                let seed = index * 29 + 113
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 7)
                let n2 = pseudoNoise(seed + 17)
                let n3 = pseudoNoise(seed + 31)
                let depth = (i + 0.55 * n0) / 54
                let y = horizonY + 10 + depth * waterHeight * 0.88
                let spread = width * (0.035 + 0.78 * depth)
                let centerX = sunCenterX
                    + (n1 - 0.5) * spread
                    + width * 0.012 * sin(t * (0.08 + 0.10 * n2) + i * 1.7)
                let halfWidth = width * (0.012 + 0.090 * depth) * (0.38 + 0.92 * n2)
                let phase = t * (0.26 + 0.30 * n0) + n3 * .pi * 2
                let shimmer = 0.42 + 0.58 * (0.5 + 0.5 * sin(t * (0.34 + 0.42 * n2) + n1 * .pi * 2))
                let amplitude = 1.0 + 6.5 * depth * (0.45 + n1)
                let opacity = (0.055 + 0.18 * Double(breath))
                    * Double(1 - depth * 0.58)
                    * Double(0.32 + 0.80 * n2)
                    * Double(shimmer)
                let path = wavePath(
                    startX: centerX - halfWidth,
                    endX: centerX + halfWidth,
                    y: y,
                    amplitude: amplitude,
                    phase: phase,
                    segments: n3 > 0.62 ? 3 : 2
                )

                layer.stroke(
                    path,
                    with: .color(Color(red: 1.0, green: 0.66 + 0.08 * Double(n1), blue: 0.42).opacity(opacity)),
                    style: StrokeStyle(lineWidth: 0.45 + 1.25 * breath + 0.85 * n0, lineCap: .round, lineJoin: .round)
                )
            }
        }

        for index in 0..<34 {
            let seed = index * 43 + 227
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 13)
            let n2 = pseudoNoise(seed + 29)
            let n3 = pseudoNoise(seed + 41)
            let depth = (CGFloat(index) + 0.7 * n0) / 34
            let y = horizonY + 18 + depth * waterHeight * 0.82
            let spread = width * (0.05 + 0.58 * depth)
            let centerX = sunCenterX + (n1 - 0.5) * spread
            let halfWidth = width * (0.020 + 0.060 * n2) * (0.72 + 0.58 * depth)
            let phase = t * (0.34 + 0.22 * n1) + n3 * .pi * 2
            let brightness = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.40 + 0.38 * n0) + n2 * .pi * 2))
            let path = wavePath(
                startX: centerX - halfWidth,
                endX: centerX + halfWidth,
                y: y,
                amplitude: 1.5 + 7.0 * depth * (0.5 + n3),
                phase: phase,
                segments: 2
            )

            context.stroke(
                path,
                with: .color(Color(red: 1.0, green: 0.70, blue: 0.44).opacity((0.055 + 0.15 * Double(breath)) * Double(1 - depth * 0.74) * Double(brightness))),
                style: StrokeStyle(lineWidth: 0.55 + 1.05 * breath + 0.55 * n2, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private static func drawOceanSurface(
        in context: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        breath: CGFloat,
        time: TimeInterval,
        sunCenterX: CGFloat
    ) {
        let width = size.width
        let waterHeight = max(1, size.height - horizonY)
        let t = CGFloat(time)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.45))

            for index in 0..<38 {
                let seed = index * 29 + 5
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 11)
                let n2 = pseudoNoise(seed + 23)
                let n3 = pseudoNoise(seed + 37)
                let depth = (CGFloat(index) + 0.65 * n0) / 38
                let y = horizonY + 9 + depth * waterHeight * 0.96
                let drift = width * 0.035 * sin(t * (0.06 + 0.08 * n2) + CGFloat(index) * 0.91)
                let startX = width * (-0.18 + 1.34 * n1) + drift
                let length = width * (0.11 + 0.30 * n2) * (0.72 + 0.84 * depth)
                let amplitude = 1.3 + 9.0 * depth * (0.45 + n3)
                let phase = t * (0.16 + 0.24 * n0) + CGFloat(index) * 0.57
                let opacity = (0.030 + 0.040 * Double(1 - depth) + 0.030 * Double(breath)) * Double(0.55 + 0.55 * n2)
                let path = wavePath(
                    startX: startX,
                    endX: startX + length,
                    y: y,
                    amplitude: amplitude,
                    phase: phase,
                    segments: depth < 0.25 ? 2 : 4
                )

                layer.stroke(
                    path,
                    with: .color(Color(red: 0.72, green: 0.88, blue: 1.0).opacity(opacity)),
                    style: StrokeStyle(lineWidth: 0.8 + 0.8 * depth + 0.5 * n0, lineCap: .round, lineJoin: .round)
                )
            }
        }

        for index in 0..<18 {
            let seed = index * 31 + 211
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 13)
            let n2 = pseudoNoise(seed + 29)
            let depth = (CGFloat(index) + 0.35 * n0) / 18
            let y = horizonY + waterHeight * (0.08 + 0.82 * depth)
            let sunPull = 1 - abs(depth - 0.36)
            let x = sunCenterX + (n1 - 0.5) * width * (0.22 + 0.70 * depth)
            let length = width * (0.035 + 0.13 * n2) * (0.8 + 0.45 * sunPull)
            let phase = t * (0.23 + 0.17 * n1) + CGFloat(index) * 1.13
            let path = wavePath(
                startX: x - length,
                endX: x + length,
                y: y,
                amplitude: 2.5 + 7.0 * depth,
                phase: phase,
                segments: 3
            )

            context.stroke(
                path,
                with: .color(Color.white.opacity((0.035 + 0.06 * Double(breath)) * Double(0.35 + 0.65 * n0))),
                style: StrokeStyle(lineWidth: 0.7 + 0.8 * n2, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private static func wavePath(
        startX: CGFloat,
        endX: CGFloat,
        y: CGFloat,
        amplitude: CGFloat,
        phase: CGFloat,
        segments: Int
    ) -> Path {
        var path = Path()
        let segmentCount = max(1, segments)
        let width = endX - startX
        var current = CGPoint(x: startX, y: y + sin(phase) * amplitude)

        path.move(to: current)

        for segment in 0..<segmentCount {
            let startProgress = CGFloat(segment) / CGFloat(segmentCount)
            let endProgress = CGFloat(segment + 1) / CGFloat(segmentCount)
            let midProgress = (startProgress + endProgress) * 0.5
            let next = CGPoint(
                x: startX + width * endProgress,
                y: y + sin(phase + endProgress * .pi * 2) * amplitude
            )
            let controlY = y + sin(phase + midProgress * .pi * 2) * amplitude * 1.35
            let control1 = CGPoint(
                x: current.x + width / CGFloat(segmentCount) * 0.34,
                y: current.y
            )
            let control2 = CGPoint(
                x: startX + width * (endProgress - 0.34 / CGFloat(segmentCount)),
                y: controlY
            )

            path.addCurve(to: next, control1: control1, control2: control2)
            current = next
        }

        return path
    }

    private static func drawSoftParticles(
        in context: inout GraphicsContext,
        size: CGSize,
        count: Int,
        centerY: CGFloat,
        breath: CGFloat,
        energy: CGFloat,
        time: TimeInterval,
        color: Color
    ) {
        let width = size.width
        let height = size.height

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.5 + 2.3 * breath))

            for index in 0..<count {
                let noise = pseudoNoise(index)
                let n1 = pseudoNoise(index + 8)
                let n2 = pseudoNoise(index + 13)
                let phase = CGFloat(time) * (0.08 + 0.38 * energy + 0.08 * n1) + CGFloat(index) * 1.7
                let x = width * CGFloat(noise) + width * (0.012 + 0.030 * energy) * sin(phase * 0.7)
                let y = centerY + sin(phase) * (height * (0.018 + 0.046 * breath))
                let radius = CGFloat(0.95 + 2.45 * n2) * (0.78 + 0.50 * breath)
                let opacity = 0.12 + 0.18 * Double(energy) * Double(0.45 + pseudoNoise(index + 5))

                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: x - radius * (1.0 + 0.55 * pseudoNoise(index + 21)),
                        y: y - radius * (0.9 + 0.40 * pseudoNoise(index + 34)),
                        width: radius * (1.8 + 0.70 * pseudoNoise(index + 55)),
                        height: radius * (1.7 + 0.70 * pseudoNoise(index + 89))
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
