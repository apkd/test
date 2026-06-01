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
        let centerY = height * (0.52 - 0.035 * breath)

        for layer in 0..<7 {
            let i = CGFloat(layer)
            let n0 = pseudoNoise(layer + 41)
            let n1 = pseudoNoise(layer + 73)
            let n2 = pseudoNoise(layer + 109)
            let layerBreath = breath * (0.64 + 0.58 * n0)
            let slowPhase = CGFloat(time) * (0.12 + 0.13 * n1) + i * 1.33
            let horizontalPhase = CGFloat(time) * (0.20 + 0.18 * n2) + i * 2.17
            let counterPhase = CGFloat(time) * (0.07 + 0.11 * n0) + i * 3.41
            let horizontalShift = width * (
                0.15 * sin(horizontalPhase)
                + 0.07 * sin(counterPhase + 1.6)
                + 0.035 * cos(slowPhase * 0.6)
            )
            let layerOffset = CGFloat(layer - 3) * (10 + 8 * n1)
            let verticalFloat = sin(slowPhase) * (12 + 22 * n0) + cos(counterPhase) * (6 + 14 * layerBreath)
            let amplitude = height * (0.045 + (0.105 + 0.055 * n2) * layerBreath)
            let start = CGPoint(
                x: -width * (0.36 + 0.08 * n0) + horizontalShift * 0.55,
                y: centerY + layerOffset + verticalFloat
            )
            let first = CGPoint(
                x: width * (0.25 + 0.06 * sin(counterPhase)) + horizontalShift * (0.95 + 0.18 * n1),
                y: centerY + layerOffset - amplitude * (0.72 + 0.22 * sin(slowPhase + 0.3))
            )
            let second = CGPoint(
                x: width * (0.56 + 0.07 * cos(slowPhase)) + horizontalShift * (0.45 - 0.20 * n0),
                y: centerY + layerOffset + amplitude * (0.62 + 0.18 * cos(horizontalPhase))
            )
            let end = CGPoint(
                x: width * (1.34 + 0.10 * n2) + horizontalShift * 0.75,
                y: centerY + layerOffset + cos(horizontalPhase * 0.72) * (16 + 24 * n1)
            )
            let control1 = CGPoint(
                x: width * (0.04 + 0.08 * n1) + horizontalShift * 1.16,
                y: centerY + layerOffset - amplitude * (0.95 + 0.18 * n0) + sin(horizontalPhase) * 18
            )
            let control2 = CGPoint(
                x: width * (0.18 + 0.10 * n2) + horizontalShift * 0.72,
                y: centerY + layerOffset + amplitude * (0.38 + 0.15 * n1) + cos(counterPhase) * 20
            )
            let control3 = CGPoint(
                x: width * (0.41 + 0.10 * n0) + horizontalShift * 0.20,
                y: centerY + layerOffset - amplitude * (0.46 + 0.16 * n2) + sin(slowPhase + 0.8) * 22
            )
            let control4 = CGPoint(
                x: width * (0.73 + 0.11 * n1) + horizontalShift * 0.62,
                y: centerY + layerOffset + amplitude * (0.80 + 0.20 * n0) + cos(horizontalPhase + 1.3) * 24
            )
            let control5 = CGPoint(
                x: width * (0.82 + 0.08 * n2) + horizontalShift * 0.96,
                y: centerY + layerOffset - amplitude * (0.34 + 0.12 * n1) + sin(counterPhase + 1.9) * 18
            )
            let control6 = CGPoint(
                x: width * (1.08 + 0.08 * n0) + horizontalShift * 0.52,
                y: centerY + layerOffset + amplitude * (0.48 + 0.14 * n2) + cos(slowPhase + 0.4) * 18
            )

            var path = Path()
            path.move(to: start)
            path.addCurve(to: first, control1: control1, control2: control2)
            path.addCurve(to: second, control1: control3, control2: control4)
            path.addCurve(to: end, control1: control5, control2: control6)

            let lineWidth = 3.5 + layerBreath * 22 + CGFloat(layer) * 2.15
            let opacity = 0.11 + Double(layerBreath) * 0.12 + Double(layer) * 0.015
            let color = Color(red: 0.62, green: 0.82, blue: 1.0).opacity(opacity)

            context.drawLayer { layerContext in
                layerContext.addFilter(.blur(radius: 10 + layerBreath * 22))
                layerContext.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth * 1.9, lineCap: .round, lineJoin: .round)
                )
            }

            context.stroke(
                path,
                with: .color(Color.white.opacity(0.10 + Double(layerBreath) * 0.22)),
                style: StrokeStyle(lineWidth: max(1.6, lineWidth * 0.18), lineCap: .round, lineJoin: .round)
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
        let center = CGPoint(
            x: width * (0.51 + 0.018 * sin(CGFloat(time) * 0.10)),
            y: height * (0.47 + 0.025 * cos(CGFloat(time) * 0.07))
        )
        let reach = min(width, height) * (0.20 + 0.42 * breath)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 7 + 12 * (1 - breath)))

            for index in 0..<(reduceMotion ? 16 : 48) {
                let i = CGFloat(index)
                let angle = i * 2.399_963 + CGFloat(time) * (0.025 + 0.0011 * i)
                let wobble = sin(CGFloat(time) * 0.16 + i * 1.71)
                let distance = reach * (0.16 + 0.92 * pseudoNoise(index)) * (0.82 + 0.28 * wobble)
                let asymmetry = CGSize(
                    width: cos(angle) * distance * (1.15 + 0.24 * sin(i)),
                    height: sin(angle) * distance * (0.78 + 0.30 * cos(i * 0.7))
                )
                let particleCenter = CGPoint(
                    x: center.x + asymmetry.width,
                    y: center.y + asymmetry.height
                )
                let radius = min(width, height) * (0.034 + 0.092 * pseudoNoise(index + 19)) * (0.88 + 0.70 * breath)
                let alpha = 0.10 + 0.18 * Double(breath) * Double(0.45 + pseudoNoise(index + 7))

                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: particleCenter.x - radius,
                        y: particleCenter.y - radius * (0.8 + 0.6 * pseudoNoise(index + 3)),
                        width: radius * (1.5 + 1.3 * pseudoNoise(index + 11)),
                        height: radius * (1.6 + 1.4 * pseudoNoise(index + 5))
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.82, green: 0.62, blue: 1.0).opacity(alpha * 1.55),
                            Color(red: 0.24, green: 0.78, blue: 1.0).opacity(alpha * 0.82),
                            Color(red: 0.40, green: 0.20, blue: 0.86).opacity(alpha * 0.46),
                            .clear,
                        ]),
                        center: particleCenter,
                        startRadius: 0,
                        endRadius: radius * 1.8
                    )
                )
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 20))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - reach * 0.52,
                    y: center.y - reach * 0.44,
                    width: reach * 1.04,
                    height: reach * 0.88
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.12 + 0.13 * Double(breath)),
                        Color(red: 0.64, green: 0.55, blue: 1.0).opacity(0.24 + 0.10 * Double(breath)),
                        Color(red: 0.16, green: 0.72, blue: 1.0).opacity(0.12),
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

    private static func pseudoNoise(_ seed: Int) -> CGFloat {
        let value = sin(Double(seed) * 12.9898) * 43_758.5453
        return CGFloat(value - floor(value))
    }
}
