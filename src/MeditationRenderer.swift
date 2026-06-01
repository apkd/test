import SwiftUI

enum MeditationRenderer {
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
        let centerY = height * (0.54 - 0.018 * breath)
        let sampleCount = reduceMotion ? 48 : 86

        for layer in 0..<6 {
            let i = CGFloat(layer)
            let seed = layer * 37 + 19
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 11)
            let n2 = pseudoNoise(seed + 23)
            let n3 = pseudoNoise(seed + 41)
            let phase = CGFloat(time) * (0.18 + 0.08 * n0) + i * 1.73
            let counterPhase = CGFloat(time) * (0.10 + 0.09 * n2) + i * 2.61
            let horizontalDrift = width * (
                0.18 * sin(phase * 0.74 + i)
                + 0.08 * sin(counterPhase + 1.7)
                + 0.04 * cos(CGFloat(time) * 0.045 + i * 3.4)
            )
            let baseOffset = (i - 2.5) * (height * 0.018 + 7 * n1) + (n2 - 0.5) * height * 0.10
            let amplitudeA = height * (0.095 + 0.045 * n1) * (0.72 + 0.40 * breath)
            let amplitudeB = height * (0.030 + 0.030 * n2)
            let amplitudeC = height * (0.012 + 0.016 * n3)
            var spine: [CGPoint] = []

            for sample in 0...sampleCount {
                let progress = CGFloat(sample) / CGFloat(sampleCount)
                let envelope = sin(progress * .pi)
                let flow = progress * 2 * .pi
                let xCurl = width * 0.038 * envelope * sin(flow * (1.1 + 0.28 * n3) - phase * 0.84 + i)
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

            let ribbonPath = ribbonPath(
                through: spine,
                halfWidth: { _, progress in
                    let envelope = sin(progress * .pi)
                    let localPulse = 0.5 + 0.5 * sin(progress * 5.7 + phase * 1.4 + i)
                    return (height * (0.0048 + 0.0028 * n0) + i * 1.15)
                        * (1.0 + 1.25 * envelope)
                        * (0.82 + 0.40 * localPulse + 0.35 * breath)
                }
            )
            let spinePath = openPath(through: spine)
            let glowOpacity = 0.10 + Double(breath) * 0.08 + Double(n2) * 0.05
            let fillOpacity = 0.09 + Double(breath) * 0.08 + Double(layer) * 0.012

            context.drawLayer { layerContext in
                layerContext.addFilter(.blur(radius: 14 + 14 * n1 + 8 * breath))
                layerContext.fill(
                    ribbonPath,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.36, green: 0.66, blue: 1.0).opacity(glowOpacity * 0.65),
                            Color(red: 0.82, green: 0.93, blue: 1.0).opacity(glowOpacity),
                            Color(red: 0.58, green: 0.76, blue: 1.0).opacity(glowOpacity * 0.55),
                        ]),
                        startPoint: CGPoint(x: -width * 0.2 + horizontalDrift, y: centerY + baseOffset - amplitudeA),
                        endPoint: CGPoint(x: width * 1.18 + horizontalDrift, y: centerY + baseOffset + amplitudeA)
                    )
                )
            }

            context.fill(
                ribbonPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.40, green: 0.70, blue: 1.0).opacity(fillOpacity * 0.46),
                        Color.white.opacity(fillOpacity),
                        Color(red: 0.72, green: 0.86, blue: 1.0).opacity(fillOpacity * 0.58),
                    ]),
                    startPoint: CGPoint(x: -width * 0.18 + horizontalDrift, y: centerY + baseOffset - amplitudeA),
                    endPoint: CGPoint(x: width * 1.16 + horizontalDrift, y: centerY + baseOffset + amplitudeA)
                )
            )

            context.stroke(
                spinePath,
                with: .color(Color.white.opacity(0.10 + Double(breath) * 0.10 + Double(n0) * 0.04)),
                style: StrokeStyle(lineWidth: 0.8 + 1.0 * n3, lineCap: .round, lineJoin: .round)
            )

            for filament in 0..<2 {
                let offset = CGFloat(filament == 0 ? -1 : 1) * (2.5 + 5 * n1 + i * 0.55)
                let filamentPath = offsetPath(through: spine, distance: offset)
                context.stroke(
                    filamentPath,
                    with: .color(Color(red: 0.72, green: 0.90, blue: 1.0).opacity(0.045 + Double(breath) * 0.05)),
                    style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
                )
            }
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
            y: horizonY + cameraWobble - sunRadius * (0.52 + 0.80 * breath)
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
        let center = CGPoint(
            x: width * (0.51 + 0.018 * sin(CGFloat(time) * 0.10)),
            y: height * (0.47 + 0.025 * cos(CGFloat(time) * 0.07))
        )
        let scale = min(width, height)
        let reach = scale * (0.26 + 0.34 * breath)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 22))

            for index in 0..<(reduceMotion ? 5 : 10) {
                let i = CGFloat(index)
                let n0 = pseudoNoise(index + 3)
                let n1 = pseudoNoise(index + 17)
                let angle = i * 2.399_963 + CGFloat(time) * (0.035 + 0.018 * n0)
                let localPulse = 0.5 + 0.5 * sin(CGFloat(time) * (0.12 + 0.06 * n1) + i * 1.9)
                let distance = reach * (0.10 + 0.42 * n0) * (0.75 + 0.35 * localPulse)
                let cloudCenter = CGPoint(
                    x: center.x + cos(angle) * distance * 1.25,
                    y: center.y + sin(angle) * distance * 0.85
                )
                let radius = scale * (0.14 + 0.13 * n1) * (0.85 + 0.35 * localPulse + 0.20 * fullBreath)

                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: cloudCenter.x - radius * (1.05 + n0),
                        y: cloudCenter.y - radius * (0.88 + 0.45 * n1),
                        width: radius * (1.9 + 1.2 * n0),
                        height: radius * (1.6 + 1.0 * n1)
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.78, green: 0.66, blue: 1.0).opacity(0.18 + 0.10 * Double(localPulse)),
                            Color(red: 0.20, green: 0.63, blue: 1.0).opacity(0.12 + 0.10 * Double(fullBreath)),
                            Color(red: 0.36, green: 0.18, blue: 0.78).opacity(0.08),
                            .clear,
                        ]),
                        center: cloudCenter,
                        startRadius: 0,
                        endRadius: radius * 1.8
                    )
                )
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5 + 6 * (1 - breath)))

            for index in 0..<(reduceMotion ? 16 : 48) {
                let i = CGFloat(index)
                let n0 = pseudoNoise(index)
                let n1 = pseudoNoise(index + 19)
                let n2 = pseudoNoise(index + 37)
                let n3 = pseudoNoise(index + 53)
                let angle = i * 2.399_963 + CGFloat(time) * (0.020 + 0.022 * n1)
                let localPulse = 0.5 + 0.5 * sin(CGFloat(time) * (0.18 + 0.16 * n2) + i * 1.71)
                let counterPulse = 0.5 + 0.5 * cos(CGFloat(time) * (0.09 + 0.11 * n3) + i * 0.97)
                let distance = reach * (0.13 + 0.88 * n0) * (0.70 + 0.34 * localPulse + 0.26 * breath)
                let asymmetry = CGSize(
                    width: cos(angle) * distance * (1.20 + 0.34 * sin(i * 0.61 + counterPulse)),
                    height: sin(angle) * distance * (0.76 + 0.36 * cos(i * 0.7 + localPulse))
                )
                let particleCenter = CGPoint(
                    x: center.x + asymmetry.width,
                    y: center.y + asymmetry.height
                )
                let radius = scale * (0.028 + 0.074 * n1) * (0.72 + 0.62 * localPulse + 0.40 * breath)
                let alpha = 0.14 + 0.18 * Double(localPulse) + 0.10 * Double(fullBreath)

                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: particleCenter.x - radius * (0.8 + n2),
                        y: particleCenter.y - radius * (0.8 + 0.8 * n3),
                        width: radius * (1.3 + 1.6 * n2),
                        height: radius * (1.2 + 1.7 * n3)
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(alpha * 0.34),
                            Color(red: 0.82, green: 0.62, blue: 1.0).opacity(alpha * 1.05),
                            Color(red: 0.18, green: 0.70, blue: 1.0).opacity(alpha * 0.72),
                            Color(red: 0.42, green: 0.18, blue: 0.86).opacity(alpha * 0.48),
                            .clear,
                        ]),
                        center: particleCenter,
                        startRadius: radius * 0.04,
                        endRadius: radius * 1.9
                    )
                )
            }
        }

        for index in 0..<(reduceMotion ? 7 : 18) {
            let i = CGFloat(index)
            let n0 = pseudoNoise(index + 71)
            let n1 = pseudoNoise(index + 89)
            let angle = i * 2.399_963 + CGFloat(time) * (0.025 + 0.015 * n0)
            let length = reach * (0.40 + 0.58 * n1) * (0.70 + 0.30 * breath)
            let origin = CGPoint(
                x: center.x + cos(angle + .pi) * scale * 0.030 * n0,
                y: center.y + sin(angle + .pi) * scale * 0.025 * n1
            )
            let end = CGPoint(
                x: center.x + cos(angle) * length * 1.15,
                y: center.y + sin(angle) * length * 0.78
            )
            let controlA = CGPoint(
                x: center.x + cos(angle - 0.72) * length * (0.24 + 0.20 * n0),
                y: center.y + sin(angle - 0.72) * length * (0.20 + 0.22 * n1)
            )
            let controlB = CGPoint(
                x: center.x + cos(angle + 0.64) * length * (0.62 + 0.16 * n1),
                y: center.y + sin(angle + 0.64) * length * (0.42 + 0.20 * n0)
            )
            var tendril = Path()
            tendril.move(to: origin)
            tendril.addCurve(to: end, control1: controlA, control2: controlB)
            context.stroke(
                tendril,
                with: .color(Color(red: 0.75, green: 0.60, blue: 1.0).opacity(0.045 + 0.055 * Double(n0) + 0.035 * Double(breath))),
                style: StrokeStyle(lineWidth: 0.9 + 1.5 * n1, lineCap: .round, lineJoin: .round)
            )
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - reach * 0.48,
                    y: center.y - reach * 0.40,
                    width: reach * 0.96,
                    height: reach * 0.80
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

        for index in 0..<count {
            let noise = pseudoNoise(index)
            let x = width * CGFloat(noise)
            let y = centerY + CGFloat(sin(Double(index) * 1.7 + time * 0.32)) * (34 + 48 * breath)
            let radius = CGFloat(1.2 + 3.8 * pseudoNoise(index + 13)) * (0.8 + breath)

            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(0.06 + 0.12 * Double(breath) * Double(pseudoNoise(index + 5))))
            )
        }
    }

    private static func openPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else {
            return path
        }

        path.move(to: first)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }

    private static func offsetPath(through points: [CGPoint], distance: CGFloat) -> Path {
        openPath(through: offsetPoints(through: points, distance: distance))
    }

    private static func ribbonPath(through points: [CGPoint], halfWidth: (Int, CGFloat) -> CGFloat) -> Path {
        guard points.count > 1 else {
            return Path()
        }

        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        let last = points.count - 1

        for index in points.indices {
            let normal = normalVector(in: points, at: index)
            let progress = CGFloat(index) / CGFloat(last)
            let distance = halfWidth(index, progress)
            let point = points[index]

            upper.append(CGPoint(x: point.x + normal.width * distance, y: point.y + normal.height * distance))
            lower.append(CGPoint(x: point.x - normal.width * distance, y: point.y - normal.height * distance))
        }

        var path = Path()
        path.move(to: upper[0])

        for point in upper.dropFirst() {
            path.addLine(to: point)
        }

        for point in lower.reversed() {
            path.addLine(to: point)
        }

        path.closeSubpath()
        return path
    }

    private static func offsetPoints(through points: [CGPoint], distance: CGFloat) -> [CGPoint] {
        points.indices.map { index in
            let normal = normalVector(in: points, at: index)
            let point = points[index]
            return CGPoint(x: point.x + normal.width * distance, y: point.y + normal.height * distance)
        }
    }

    private static func normalVector(in points: [CGPoint], at index: Int) -> CGSize {
        let previous = points[max(points.startIndex, index - 1)]
        let next = points[min(points.index(before: points.endIndex), index + 1)]
        let dx = next.x - previous.x
        let dy = next.y - previous.y
        let length = max(0.001, sqrt(dx * dx + dy * dy))

        return CGSize(width: -dy / length, height: dx / length)
    }

    private static func pseudoNoise(_ seed: Int) -> CGFloat {
        let value = sin(Double(seed) * 12.9898) * 43_758.5453
        return CGFloat(value - floor(value))
    }
}
