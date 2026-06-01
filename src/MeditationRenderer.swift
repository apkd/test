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
        let drift = CGFloat(time * 0.16)
        let centerY = height * (0.53 - 0.08 * breath)
        let amplitude = height * (0.035 + 0.12 * breath)

        for layer in 0..<6 {
            let layerOffset = CGFloat(layer - 2) * (8 + breath * 6)
            let phase = drift + CGFloat(layer) * 0.72
            let start = CGPoint(x: -width * 0.18, y: centerY + layerOffset + sin(phase) * 12)
            let end = CGPoint(x: width * 1.18, y: centerY + layerOffset + cos(phase * 0.8) * 12)
            let control1 = CGPoint(
                x: width * 0.18,
                y: centerY - amplitude * (0.85 + 0.12 * CGFloat(layer)) + sin(phase + 0.7) * 18
            )
            let control2 = CGPoint(
                x: width * 0.76,
                y: centerY + amplitude * (0.72 + 0.06 * CGFloat(layer)) + cos(phase + 1.3) * 18
            )

            var path = Path()
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)

            let lineWidth = 4 + breath * 19 + CGFloat(layer) * 2.5
            let opacity = 0.12 + Double(breath) * 0.09 + Double(layer) * 0.018
            let color = Color(red: 0.62, green: 0.82, blue: 1.0).opacity(opacity)

            context.drawLayer { layerContext in
                layerContext.addFilter(.blur(radius: 10 + breath * 22))
                layerContext.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth * 1.9, lineCap: .round, lineJoin: .round)
                )
            }

            context.stroke(
                path,
                with: .color(Color.white.opacity(0.10 + Double(breath) * 0.22)),
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
        let horizonY = height * (0.60 - 0.105 * breath)
        let sunRadius = min(width, height) * (0.135 + 0.035 * breath)
        let sunCenter = CGPoint(
            x: width * (0.5 + 0.018 * sin(CGFloat(time) * 0.08)),
            y: horizonY - sunRadius * (0.34 + 0.18 * breath)
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
            layer.addFilter(.blur(radius: 28 + 24 * breath))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: sunCenter.x - sunRadius * 2.4,
                    y: sunCenter.y - sunRadius * 2.2,
                    width: sunRadius * 4.8,
                    height: sunRadius * 4.8
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.74, blue: 0.45).opacity(0.74),
                        Color(red: 0.96, green: 0.32, blue: 0.38).opacity(0.26),
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
        horizon.move(to: CGPoint(x: 0, y: horizonY))
        horizon.addLine(to: CGPoint(x: width, y: horizonY))
        context.stroke(
            horizon,
            with: .color(Color.white.opacity(0.35 + Double(breath) * 0.18)),
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
        let reach = min(width, height) * (0.14 + 0.30 * breath)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 12 + 18 * (1 - breath)))

            for index in 0..<(reduceMotion ? 10 : 26) {
                let i = CGFloat(index)
                let angle = i * 2.399_963 + CGFloat(time) * (0.018 + 0.0008 * i)
                let wobble = sin(CGFloat(time) * 0.12 + i * 1.71)
                let distance = reach * (0.22 + 0.78 * pseudoNoise(index)) * (0.72 + 0.22 * wobble)
                let asymmetry = CGSize(
                    width: cos(angle) * distance * (1.08 + 0.18 * sin(i)),
                    height: sin(angle) * distance * (0.76 + 0.22 * cos(i * 0.7))
                )
                let particleCenter = CGPoint(
                    x: center.x + asymmetry.width,
                    y: center.y + asymmetry.height
                )
                let radius = min(width, height) * (0.020 + 0.065 * pseudoNoise(index + 19)) * (0.72 + 0.55 * breath)
                let alpha = 0.045 + 0.10 * Double(breath) * Double(0.35 + pseudoNoise(index + 7))

                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: particleCenter.x - radius,
                        y: particleCenter.y - radius * (0.8 + 0.6 * pseudoNoise(index + 3)),
                        width: radius * (1.5 + 1.3 * pseudoNoise(index + 11)),
                        height: radius * (1.6 + 1.4 * pseudoNoise(index + 5))
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.77, green: 0.58, blue: 1.0).opacity(alpha * 1.4),
                            Color(red: 0.24, green: 0.76, blue: 0.96).opacity(alpha * 0.55),
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
            layer.addFilter(.blur(radius: 18))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - reach * 0.36,
                    y: center.y - reach * 0.30,
                    width: reach * 0.72,
                    height: reach * 0.60
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.08 + 0.09 * Double(breath)),
                        Color(red: 0.64, green: 0.55, blue: 1.0).opacity(0.12),
                        .clear,
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: reach * 0.42
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
