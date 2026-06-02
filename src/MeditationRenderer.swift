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
        let inhaleDrive = (snapshot.isInhale ? phaseEase : 1 - phaseEase) * motionScale
        let slowPhase = CGFloat(time) * (2 * .pi / 150)
        let strandCount = reduceMotion ? 9 : 11
        let sampleCount = reduceMotion ? 80 : 108
        let bundleHalfWidth = min(width, height) * (0.030 + 0.010 * breath) * motionScale
        var strings: [LightString] = []
        var branchStrings: [LightString] = []

        func centerPoint(progress: CGFloat, phase: CGFloat) -> CGPoint {
            let envelope = pow(max(0, sin(progress * .pi)), 0.72)
            let x = width * (0.095 + 0.815 * progress)
            let y = height * (
                0.570
                - 0.255 * progress
                + 0.150 * envelope * sin(2 * .pi * (progress - 0.10) + phase * 0.085)
                + 0.018 * envelope * sin(4 * .pi * progress - phase * 0.05)
                - 0.012 * breath * motionScale
            )
            return CGPoint(x: x, y: y)
        }

        func tangentNormal(progress: CGFloat, phase: CGFloat) -> (tangent: CGVector, normal: CGVector) {
            let delta: CGFloat = 0.003
            let previous = centerPoint(progress: max(0, progress - delta), phase: phase)
            let next = centerPoint(progress: min(1, progress + delta), phase: phase)
            let dx = next.x - previous.x
            let dy = next.y - previous.y
            let length = max(1, sqrt(dx * dx + dy * dy))
            let tangent = CGVector(dx: dx / length, dy: dy / length)
            let normal = CGVector(dx: -tangent.dy, dy: tangent.dx)
            return (tangent, normal)
        }

        func strandPoint(progress: CGFloat, lane: CGFloat, seed: CGFloat, phase: CGFloat) -> CGPoint {
            let center = centerPoint(progress: progress, phase: phase)
            let vectors = tangentNormal(progress: progress, phase: phase)
            let envelope = 0.66 + 0.34 * pow(max(0, sin(progress * .pi)), 0.76)
            let flow = progress * 2 * .pi
            let wiggle = min(width, height) * 0.0024 * (
                sin(flow * (1.20 + 0.12 * seed) + seed * 5.7 + phase * 0.40)
                + 0.45 * sin(flow * 2.15 + seed * 9.4 - phase * 0.30)
            ) * motionScale
            let perspective = (progress - 0.50) * width * 0.016 * (0.40 + 0.60 * (1 - abs(lane)))
            let offset = lane * bundleHalfWidth * envelope + wiggle
            return CGPoint(
                x: center.x + vectors.normal.dx * offset + vectors.tangent.dx * perspective,
                y: center.y + vectors.normal.dy * offset + vectors.tangent.dy * perspective
            )
        }

        for strand in 0..<strandCount {
            let index = CGFloat(strand)
            let midpoint = max(1, CGFloat(strandCount - 1) * 0.5)
            let rawLane = (index - CGFloat(strandCount - 1) * 0.5) / midpoint
            let lane = rawLane == 0 ? 0 : (rawLane > 0 ? 1 : -1) * pow(abs(rawLane), 1.08)
            let laneAbs = abs(lane)
            let seed = pseudoNoise(strand * 53 + 19)
            let localCycle = wrappedUnit(snapshot.cycleProgress + Double(lane) * 0.012 + Double(seed - 0.5) * 0.018)
            let localBreath = CGFloat(breathAmount(atCycleProgress: localCycle))
            let phase = slowPhase + lane * 0.08 + (seed - 0.5) * 0.08
            var spine: [CGPoint] = []

            for sample in 0...sampleCount {
                let progress = CGFloat(sample) / CGFloat(sampleCount)
                spine.append(strandPoint(progress: progress, lane: lane, seed: seed, phase: phase))
            }

            let centerWeight = 1 - laneAbs
            let color = lightStringColor(index: strand, seed: seed, breath: localBreath)
            let accentMultiplier: Double = strand == strandCount - 2 ? 0.62 : 1
            let coreOpacity = (0.24 + 0.34 * Double(centerWeight) + 0.05 * Double(seed))
                * Double(0.92 + 0.12 * localBreath)
                * accentMultiplier
            let glowOpacity = (0.020 + 0.034 * Double(centerWeight) + 0.006 * Double(seed))
                * Double(0.90 + 0.12 * localBreath)
                * accentMultiplier

            strings.append(
                LightString(
                    path: smoothPath(through: spine),
                    color: color,
                    glowWidth: (6.8 + 8.0 * centerWeight + 2.0 * seed) * (0.95 + 0.10 * localBreath),
                    coreWidth: (0.58 + 0.98 * centerWeight + 0.22 * seed) * (0.95 + 0.08 * localBreath),
                    glowOpacity: glowOpacity,
                    coreOpacity: coreOpacity
                )
            )
        }

        let branchCount = reduceMotion ? 2 : 3
        for branch in 0..<branchCount {
            let seed = pseudoNoise(branch * 61 + 7)
            let branchOffset = CGFloat(branch - 1) * min(width, height) * 0.006
            let color = branch == 1
                ? Color(red: 0.35, green: 0.82, blue: 1.0)
                : Color(red: 0.16, green: 0.56, blue: 1.0)
            var points: [CGPoint] = []

            for sample in 0...70 {
                let progress = CGFloat(sample) / 70
                let theta = (34 + 292 * progress) * .pi / 180
                let radiusFalloff = 1 - 0.24 * progress
                let cx = width * (0.245 + 0.006 * sin(slowPhase + seed))
                let cy = height * (0.582 + 0.010 * cos(slowPhase * 0.7 + seed))
                let rx = width * 0.083 + branchOffset
                let ry = height * 0.052 + branchOffset * 0.64
                points.append(CGPoint(
                    x: cx + rx * radiusFalloff * cos(theta),
                    y: cy + ry * radiusFalloff * sin(theta)
                ))
            }

            branchStrings.append(
                LightString(
                    path: smoothPath(through: points),
                    color: color,
                    glowWidth: 7.0 + 2.0 * seed,
                    coreWidth: 0.55 + 0.25 * seed,
                    glowOpacity: 0.018 + 0.008 * Double(inhaleDrive),
                    coreOpacity: 0.20 + 0.07 * Double(inhaleDrive)
                )
            )
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 18))
            layerContext.fill(
                Path(ellipseIn: CGRect(
                    x: width * 0.08,
                    y: height * 0.510,
                    width: width * 0.78,
                    height: height * 0.220
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.02, green: 0.22, blue: 0.72).opacity(0.12 + 0.04 * Double(breath)),
                        Color(red: 0.00, green: 0.11, blue: 0.35).opacity(0.06),
                        .clear,
                    ]),
                    center: CGPoint(x: width * 0.42, y: height * 0.62),
                    startRadius: 0,
                    endRadius: width * 0.48
                )
            )
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 12 + 1.5 * breath))
            for string in branchStrings + strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.glowOpacity * 0.82)),
                    style: StrokeStyle(lineWidth: string.glowWidth * 1.70, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 2.6 + 0.6 * breath))
            for string in branchStrings + strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.glowOpacity * 1.92)),
                    style: StrokeStyle(lineWidth: string.glowWidth * 0.44, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 0.16))
            for string in branchStrings + strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.coreOpacity)),
                    style: StrokeStyle(lineWidth: string.coreWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            for index in [strandCount / 2 - 1, strandCount / 2, strandCount / 2 + 1] where index >= 0 && index < strings.count {
                let string = strings[index]
                layerContext.stroke(
                    string.path.trimmedPath(from: 0.06, to: 0.96),
                    with: .color(Color(red: 0.88, green: 0.98, blue: 1.0).opacity(string.coreOpacity * 0.34)),
                    style: StrokeStyle(lineWidth: max(0.34, string.coreWidth * 0.28), lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 0.55))
            for sparkIndex in 0..<(reduceMotion ? 10 : 20) {
                let n0 = pseudoNoise(sparkIndex * 17 + 5)
                let n1 = pseudoNoise(sparkIndex * 17 + 11)
                let n2 = pseudoNoise(sparkIndex * 17 + 23)
                let progress = 0.12 + 0.78 * n0
                let lane = -0.86 + 1.72 * n1
                let point = strandPoint(progress: progress, lane: lane, seed: n2, phase: slowPhase + n2 * 0.1)
                let radius = 0.45 + 0.90 * pseudoNoise(sparkIndex * 17 + 41)
                let opacity = 0.12 + 0.18 * Double(1 - abs(lane)) * Double(0.78 + 0.22 * inhaleDrive)
                let color = sparkIndex % 6 == 0
                    ? Color(red: 1.0, green: 0.22, blue: 0.76)
                    : Color(red: 0.68, green: 0.94, blue: 1.0)
                layerContext.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.24), .clear]),
                        center: point,
                        startRadius: 0,
                        endRadius: radius * 2.2
                    )
                )
            }
        }
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
                    Color(red: 0.42, green: 0.51, blue: 0.92).opacity(0.12 + 0.045 * Double(breath)),
                    Color(red: 0.34, green: 0.43, blue: 0.82).opacity(0.105 + 0.036 * Double(breath)),
                    Color(red: 0.26, green: 0.34, blue: 0.68).opacity(0.083 + 0.030 * Double(breath)),
                    Color(red: 0.19, green: 0.25, blue: 0.54).opacity(0.060 + 0.024 * Double(breath)),
                    Color(red: 0.12, green: 0.17, blue: 0.38).opacity(0.035 + 0.016 * Double(breath)),
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

        drawSoftGlowGrain(in: &context, size: size, count: reduceMotion ? 700 : 2_400, alphaScale: reduceMotion ? 1.05 : 1.55)
    }

    private static func drawSoftGlowGrain(
        in context: inout GraphicsContext,
        size: CGSize,
        count: Int,
        alphaScale: Double
    ) {
        for index in 0..<count {
            let n0 = pseudoNoise(index * 73 + 17)
            let n1 = pseudoNoise(index * 73 + 31)
            let n2 = pseudoNoise(index * 73 + 59)
            let radius = 0.18 + 0.58 * n2
            let alpha = (0.0040 + 0.0090 * Double(pseudoNoise(index * 73 + 83))) * alphaScale
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

            for index in 0..<78 {
                let i = CGFloat(index)
                let seed = index * 29 + 113
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 7)
                let n2 = pseudoNoise(seed + 17)
                let n3 = pseudoNoise(seed + 31)
                let depth = (i + 0.55 * n0) / 78
                let nearSun = max(0, 1 - depth * 1.55)
                let y = horizonY + 6 + depth * waterHeight * 0.90
                let spread = width * (0.085 * nearSun + 0.050 + 0.74 * depth)
                let centerX = sunCenterX
                    + (n1 - 0.5) * spread
                    + width * 0.012 * sin(t * (0.08 + 0.10 * n2) + i * 1.7)
                let halfWidth = width * (0.055 * nearSun + 0.016 + 0.078 * depth) * (0.50 + 0.95 * n2)
                let phase = t * (0.26 + 0.30 * n0) + n3 * .pi * 2
                let shimmer = 0.42 + 0.58 * (0.5 + 0.5 * sin(t * (0.34 + 0.42 * n2) + n1 * .pi * 2))
                let amplitude = 0.8 + 7.2 * depth * (0.45 + n1)
                let opacity = (0.105 + 0.18 * Double(breath))
                    * Double(1 - depth * 0.54)
                    * Double(0.42 + 0.86 * n2)
                    * Double(0.84 + 0.50 * nearSun)
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
                    style: StrokeStyle(lineWidth: 0.60 + 1.25 * breath + 0.95 * n0 + 0.70 * nearSun, lineCap: .round, lineJoin: .round)
                )
            }
        }

        for index in 0..<48 {
            let seed = index * 43 + 227
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 13)
            let n2 = pseudoNoise(seed + 29)
            let n3 = pseudoNoise(seed + 41)
            let depth = (CGFloat(index) + 0.7 * n0) / 48
            let nearSun = max(0, 1 - depth * 1.35)
            let y = horizonY + 12 + depth * waterHeight * 0.84
            let spread = width * (0.10 * nearSun + 0.060 + 0.60 * depth)
            let centerX = sunCenterX + (n1 - 0.5) * spread
            let halfWidth = width * (0.045 * nearSun + 0.022 + 0.064 * n2) * (0.78 + 0.58 * depth)
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
                with: .color(Color(red: 1.0, green: 0.70, blue: 0.44).opacity((0.095 + 0.15 * Double(breath)) * Double(1 - depth * 0.70) * Double(brightness) * Double(0.85 + 0.55 * nearSun))),
                style: StrokeStyle(lineWidth: 0.70 + 1.05 * breath + 0.65 * n2 + 0.50 * nearSun, lineCap: .round, lineJoin: .round)
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
            layer.addFilter(.blur(radius: 0.8 + 1.1 * breath))

            for index in 0..<count {
                let noise = pseudoNoise(index)
                let n1 = pseudoNoise(index + 8)
                let n2 = pseudoNoise(index + 13)
                let phase = CGFloat(time) * (2 * .pi / CGFloat(28 + 24 * n1)) + CGFloat(index) * 1.7
                let x = width * CGFloat(noise) + width * (0.004 + 0.010 * energy) * sin(phase * 0.7)
                let y = centerY + sin(phase) * (height * (0.014 + 0.030 * breath))
                let radius = CGFloat(0.35 + 0.72 * n2) * (0.86 + 0.24 * breath)
                let opacity = 0.08 + 0.11 * Double(energy) * Double(0.45 + pseudoNoise(index + 5))

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

    private static func wrappedUnit(_ value: Double) -> Double {
        let wrapped = value - floor(value)
        return wrapped < 0 ? wrapped + 1 : wrapped
    }

    private static func breathAmount(atCycleProgress progress: Double) -> Double {
        let wrapped = wrappedUnit(progress)
        let phaseProgress = wrapped < 0.5 ? wrapped * 2 : (wrapped - 0.5) * 2
        let eased = BreathingTimeline.smoothstep(phaseProgress)
        return wrapped < 0.5 ? eased : 1 - eased
    }

    private static func lightStringColor(index: Int, seed: CGFloat, breath: CGFloat) -> Color {
        let warmth = Double(breath) * 0.030
        let jitter = Double(seed - 0.5) * 0.012

        switch index % 16 {
        case 0, 3, 8, 11:
            return Color(red: 0.18 + warmth * 0.30, green: 0.66 + warmth * 0.50 + jitter, blue: 1.0)
        case 1, 6, 10, 14:
            return Color(red: 0.44 + warmth * 0.40, green: 0.86 + warmth * 0.35 + jitter, blue: 1.0)
        case 2, 7, 12:
            return Color(red: 0.76 + warmth + jitter, green: 0.95 + warmth * 0.35, blue: 1.0)
        case 4, 9, 13:
            return Color(red: 0.45 + warmth * 0.20, green: 0.40 + warmth * 0.18 + jitter, blue: 1.0)
        case 5:
            return Color(red: 1.0, green: 0.24 + warmth * 0.24, blue: 0.78 + jitter)
        case 15:
            return Color(red: 1.0, green: 0.72 + warmth * 0.35 + jitter, blue: 0.30 + warmth * 0.18)
        default:
            return Color(red: 0.12 + warmth * 0.20, green: 0.54 + warmth * 0.40, blue: 0.94 + jitter)
        }
    }

    private static func pseudoNoise(_ seed: Int) -> CGFloat {
        let value = sin(Double(seed) * 12.9898) * 43_758.5453
        return CGFloat(value - floor(value))
    }
}
