import SwiftUI

enum MeditationRenderer {
    private struct LightString {
        let path: Path
        let color: Color
        let auraWidth: CGFloat
        let bodyWidth: CGFloat
        let coreWidth: CGFloat
        let auraOpacity: Double
        let bodyOpacity: Double
        let coreOpacity: Double
        let pulsePosition: CGFloat
        let pulseWidth: CGFloat
        let pulseOpacity: Double
        let isFrontCore: Bool
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
        let breathEase = CGFloat(BreathingTimeline.smoothstep(snapshot.breathAmount))
        let focus = 1 - breathEase
        let cyclePhase = CGFloat(snapshot.angle)
        let ribbonMotionPace: CGFloat = 4.0 / 9.0
        let reversibleFlow = CGFloat(snapshot.breathAmount) * ribbonMotionPace
        let ribbonTime = time * TimeInterval(ribbonMotionPace)
        let continuousTime = CGFloat(ribbonTime)
        let familyCount = 3
        let strandsPerFamily = reduceMotion ? 4 : 4
        let sampleCount = reduceMotion ? 34 : 36
        let minSide = min(width, height)
        let spread = (0.62 + 0.54 * breathEase) * motionScale
        let brightness = 0.96 + 0.50 * breathEase
        var strings: [LightString] = []

        func mix(_ a: CGFloat, _ b: CGFloat, amount: CGFloat) -> CGFloat {
            a + (b - a) * amount
        }

        func smooth(_ value: CGFloat) -> CGFloat {
            let x = min(1, max(0, value))
            return x * x * (3 - 2 * x)
        }

        func smoothNoise(_ value: CGFloat, seed: Int) -> CGFloat {
            let lower = floor(value)
            let fraction = value - lower
            let base = Int(lower)
            let a = pseudoNoise(seed + base * 1_619)
            let b = pseudoNoise(seed + (base + 1) * 1_619)
            return mix(a, b, amount: smooth(fraction))
        }

        func signedNoise(_ value: CGFloat, seed: Int) -> CGFloat {
            smoothNoise(value, seed: seed) * 2 - 1
        }

        func fbm(_ value: CGFloat, seed: Int) -> CGFloat {
            var amplitude: CGFloat = 0.56
            var frequency: CGFloat = 1
            var sum: CGFloat = 0
            var total: CGFloat = 0

            for octave in 0..<4 {
                sum += signedNoise(value * frequency, seed: seed + octave * 4_091) * amplitude
                total += amplitude
                amplitude *= 0.52
                frequency *= 2.03
            }

            return sum / max(0.001, total)
        }

        func rotatedPoint(x: CGFloat, y: CGFloat, angle: CGFloat) -> CGPoint {
            let center = CGPoint(x: 0.50, y: 0.498)
            let dx = x - center.x
            let dy = y - center.y
            let cosine = cos(angle)
            let sine = sin(angle)
            return CGPoint(
                x: width * (center.x + dx * cosine - dy * sine),
                y: height * (center.y + dx * sine + dy * cosine)
            )
        }

        func paletteColor(family: Int, strand: Int, lane: CGFloat, seed: CGFloat, localBreath: CGFloat) -> Color {
            let palettes: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
                (0.22, 0.78, 1.00),
                (0.42, 0.58, 1.00),
                (0.66, 0.48, 1.00),
            ]
            var base = palettes[family % palettes.count]
            let centerAccent = abs(lane) < 0.18
            let magenta = family == 2 && (strand + family) % 3 == 1
            let jitter = (seed - 0.5) * 0.018

            if magenta {
                base = (
                    mix(base.r, 0.92, amount: 0.18),
                    mix(base.g, 0.30, amount: 0.14),
                    mix(base.b, 0.96, amount: 0.10)
                )
            }

            let warmMix = min(0.26, 0.030 + localBreath * 0.135 + (centerAccent ? 0.040 : 0))
            let warm = (r: CGFloat(0.98), g: CGFloat(0.42), b: CGFloat(0.86))
            return Color(
                red: Double(min(1, max(0, mix(base.r, warm.r, amount: warmMix) + jitter))),
                green: Double(min(1, max(0, mix(base.g, warm.g, amount: warmMix * 0.62) + jitter * 0.35))),
                blue: Double(min(1, max(0, mix(base.b, warm.b, amount: warmMix * 0.32))))
            )
        }

        for family in 0..<familyCount {
            let familySeed = family * 239 + 37
            let familyOffset = (CGFloat(family) - CGFloat(familyCount - 1) * 0.5) * 0.044
            let familySign: CGFloat = family.isMultiple(of: 2) ? 1 : -1
            let naturalOffset = familyOffset * (0.30 + 0.70 * breathEase)
            let familyNoise = pseudoNoise(familySeed)
            let depth = 0.58 + 0.42 * pseudoNoise(familySeed + 13)
            let amplitude = 0.045 + 0.020 * pseudoNoise(familySeed + 29) + 0.038 * breathEase
            let bandWidth = minSide * (0.037 + 0.014 * pseudoNoise(familySeed + 41)) * spread * (0.82 + 0.24 * depth)
            // Keep time independent from breath-dependent coefficients: `time * breathEase`
            // makes apparent speed grow with elapsed time. Cycle influence stays sinusoidal
            // so the ribbon field is continuous when the breathing cycle wraps.
            let familyPhase = continuousTime * 0.010 * (0.82 + 0.42 * familyNoise)
                + CGFloat(family) * 0.17
                + reversibleFlow * (0.90 + 0.35 * familyNoise)
                + 0.34 * sin(cyclePhase + familyNoise * 2.7)
                + 0.14 * sin(2 * cyclePhase + CGFloat(family) * 0.9)
            let rotation = (-0.044 + 0.034 * CGFloat(family))
                + 0.014 * sin(cyclePhase + familyNoise * 4.0)

            func centerPoint(progress rawProgress: CGFloat) -> CGPoint {
                let progress = min(1, max(0, rawProgress))
                let envelope = pow(max(0, sin(progress * .pi)), 0.64)
                let drift = familyPhase * 0.38
                let warp = 0.038 * envelope * signedNoise(progress * 2.14 + drift + familyNoise * 6.0, seed: familySeed + 101)
                let t = min(1.08, max(-0.08, progress + warp))
                let macro = sin(2 * .pi * (t * (0.82 + 0.18 * familyNoise) + 0.10 * CGFloat(family)) + familyPhase * 0.86)
                let counter = sin(2 * .pi * (t * (1.74 + 0.16 * pseudoNoise(familySeed + 5)) + 0.27 * familyNoise) - familyPhase * 0.54)
                let fine = fbm(t * 3.1 + familyPhase * 0.21 + familyNoise * 5.0, seed: familySeed + 131)
                let xNoise = 0.012 * envelope * fbm(t * 2.2 - familyPhase * 0.16, seed: familySeed + 151)
                let x = -0.115 + 1.235 * progress + xNoise + 0.014 * envelope * macro
                let crossingPull = sin((progress - 0.5) * .pi)
                let centerPull = naturalOffset * crossingPull * (0.76 + 0.24 * breathEase) - familyOffset * focus * 0.05
                let longArc = 0.021 * sin((progress - 0.08) * .pi * 2)
                let knot = exp(-pow((progress - 0.51) / 0.18, 2))
                let twist = familySign * knot * 0.052
                    * sin((progress - 0.5) * .pi * 3.0 + CGFloat(family) * 1.17 + familyPhase * 0.76)
                let y = 0.598
                    - 0.214 * progress
                    + centerPull
                    + longArc * envelope
                    + twist
                    + envelope * amplitude * (0.64 * macro + 0.26 * counter + 0.30 * fine)
                    - 0.012 * breathEase

                return rotatedPoint(x: x, y: y, angle: rotation)
            }

            func tangentNormal(progress: CGFloat) -> (tangent: CGVector, normal: CGVector) {
                let delta: CGFloat = 0.004
                let previous = centerPoint(progress: progress - delta)
                let next = centerPoint(progress: progress + delta)
                let dx = next.x - previous.x
                let dy = next.y - previous.y
                let length = max(1, sqrt(dx * dx + dy * dy))
                let tangent = CGVector(dx: dx / length, dy: dy / length)
                let normal = CGVector(dx: -tangent.dy, dy: tangent.dx)
                return (tangent, normal)
            }

            func strandPoint(progress: CGFloat, lane: CGFloat, seed: CGFloat, localBreath: CGFloat, strandPhase: CGFloat) -> CGPoint {
                let center = centerPoint(progress: progress)
                let vectors = tangentNormal(progress: progress)
                let envelope = pow(max(0, sin(progress * .pi)), 0.74)
                let knot = exp(-pow((progress - 0.51) / 0.17, 2))
                let flow = progress * 2 * .pi
                let weaveNoise = signedNoise(progress * 3.55 + strandPhase * 0.42 + seed * 4.0, seed: familySeed + 173)
                let harmonicWeave = sin(flow * (1.48 + seed * 0.28) + strandPhase * 1.05 + seed * 5.4)
                    + 0.42 * sin(flow * (2.36 + seed * 0.22) - strandPhase * 0.72 + seed * 8.3)
                let localSpread = 0.88 + 0.28 * localBreath
                let waist = 0.34 + 0.66 * pow(abs(progress - 0.5) * 2, 0.72)
                let braid = knot * bandWidth * 0.34
                    * sin((progress - 0.5) * .pi * 4.25 + strandPhase * 1.18 + lane * 2.0 + CGFloat(family) * 0.7)
                let offset = lane * bandWidth * envelope * localSpread * waist * (1.0 - 0.34 * knot)
                    + braid
                    + minSide * (0.0032 + 0.0035 * localBreath) * (0.60 * weaveNoise + 0.40 * harmonicWeave) * motionScale
                let tangentSlip = minSide * (0.007 + 0.010 * localBreath) * envelope
                    * sin(flow * 1.19 - strandPhase * 1.18 + seed * 6.8) * motionScale
                let perspective = width * 0.018 * (progress - 0.5) * (1 - abs(lane) * 0.42)
                return CGPoint(
                    x: center.x + vectors.normal.dx * offset + vectors.tangent.dx * (tangentSlip + perspective),
                    y: center.y + vectors.normal.dy * offset + vectors.tangent.dy * (tangentSlip + perspective)
                )
            }

            for strand in 0..<strandsPerFamily {
                let strandSeed = pseudoNoise(familySeed + strand * 53 + 19)
                let index = CGFloat(strand)
                let midpoint = max(1, CGFloat(strandsPerFamily - 1) * 0.5)
                let rawLane = (index - CGFloat(strandsPerFamily - 1) * 0.5) / midpoint
                let laneSign: CGFloat = rawLane >= 0 ? 1 : -1
                let laneJitter = (strandSeed - 0.5) * 0.075
                let lane = laneSign * pow(abs(rawLane), 1.18) + laneJitter
                let laneAbs = min(1, abs(lane))
                let localCycle = wrappedUnit(
                    snapshot.cycleProgress
                        + Double(familyOffset * 0.28)
                        + Double(lane) * 0.026
                        + Double(strandSeed - 0.5) * 0.040
                )
                let localBreath = CGFloat(breathAmount(atCycleProgress: localCycle))
                let strandPhase = familyPhase + lane * 0.34 + (strandSeed - 0.5) * 0.62
                let startProgress = -0.010 + 0.018 * laneAbs + 0.004 * strandSeed
                let endProgress = 1.010 - 0.016 * laneAbs - 0.004 * strandSeed
                var spine: [CGPoint] = []

                for sample in 0...sampleCount {
                    let sampleProgress = CGFloat(sample) / CGFloat(sampleCount)
                    let progress = startProgress + (endProgress - startProgress) * sampleProgress
                    spine.append(strandPoint(progress: progress, lane: lane, seed: strandSeed, localBreath: localBreath, strandPhase: strandPhase))
                }

                let centerWeight = 1 - laneAbs
                let frontWeight = 0.70 + 0.30 * depth
                let sustainedBreath = 0.24 + 0.76 * localBreath
                let color = paletteColor(family: family, strand: strand, lane: lane, seed: strandSeed, localBreath: localBreath)
                let isFrontCore = centerWeight > 0.30 || (strand + family) % 7 == 1
                let pulseCycleOffset = 0.045 * sin(cyclePhase + CGFloat(family) * 0.8 + strandSeed * 4.1)
                    + 0.018 * sin(2 * cyclePhase + strandSeed * 7.3)
                let pulseTravel = reversibleFlow * (0.75 + 0.24 * strandSeed)
                    + 0.018 * sin(continuousTime * (0.14 + 0.06 * strandSeed) + strandSeed * 5.2)
                let pulsePosition = CGFloat(wrappedUnit(
                    Double(pulseTravel)
                        + Double(pulseCycleOffset)
                        + Double(strandSeed)
                        + Double(family) * 0.17
                ))
                let pulseWidth = 0.032 + 0.016 * strandSeed + 0.010 * sustainedBreath
                let pulseOpacity = (0.26 + 0.24 * Double(centerWeight)) * Double(0.50 + 0.50 * sustainedBreath) * Double(frontWeight)

                strings.append(
                    LightString(
                        path: smoothPath(through: spine),
                        color: color,
                        auraWidth: (12.0 + 15.0 * centerWeight + 4.0 * strandSeed) * (0.88 + 0.24 * sustainedBreath),
                        bodyWidth: (2.8 + 3.5 * centerWeight + 0.7 * strandSeed) * (0.88 + 0.20 * sustainedBreath),
                        coreWidth: (0.42 + 0.92 * centerWeight + 0.14 * strandSeed) * (0.90 + 0.14 * sustainedBreath),
                        auraOpacity: Double(0.018 + 0.022 * centerWeight) * Double(brightness) * Double(frontWeight),
                        bodyOpacity: Double(0.110 + 0.094 * centerWeight) * Double(brightness) * Double(frontWeight),
                        coreOpacity: Double(0.112 + 0.270 * centerWeight) * Double(0.90 + 0.20 * sustainedBreath) * Double(frontWeight),
                        pulsePosition: pulsePosition,
                        pulseWidth: pulseWidth,
                        pulseOpacity: pulseOpacity,
                        isFrontCore: isFrontCore
                    )
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 24))
            layerContext.fill(
                Path(ellipseIn: CGRect(
                    x: width * 0.02,
                    y: height * 0.34,
                    width: width * 0.96,
                    height: height * 0.40
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.08, green: 0.30, blue: 0.72).opacity(0.16 + 0.08 * Double(breathEase)),
                        Color(red: 0.20, green: 0.11, blue: 0.52).opacity(0.11 + 0.05 * Double(breathEase)),
                        Color(red: 0.03, green: 0.05, blue: 0.20).opacity(0.08),
                        .clear,
                    ]),
                    center: CGPoint(x: width * (0.50 + 0.03 * breathEase), y: height * 0.52),
                    startRadius: 0,
                    endRadius: width * 0.58
                )
            )
        }

        drawSilkRibbonSheets(
            in: &context,
            size: size,
            breath: breathEase,
            flow: reversibleFlow,
            time: ribbonTime,
            reduceMotion: reduceMotion
        )

        drawSilkRibbonVeils(
            in: &context,
            size: size,
            breath: breathEase,
            cyclePhase: cyclePhase,
            time: ribbonTime,
            reduceMotion: reduceMotion
        )

        let flareCenter = CGPoint(
            x: width * (0.535 + 0.012 * sin(cyclePhase)),
            y: height * (0.482 - 0.022 * breathEase)
        )

        drawSilkRibbonDustFields(
            in: &context,
            size: size,
            center: flareCenter,
            breath: breathEase,
            flow: reversibleFlow,
            time: ribbonTime,
            reduceMotion: reduceMotion
        )

        drawSilkRibbonSparkBurst(
            in: &context,
            size: size,
            center: flareCenter,
            breath: breathEase,
            flow: reversibleFlow,
            time: ribbonTime,
            reduceMotion: reduceMotion
        )

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 18))
            layerContext.fill(
                Path(ellipseIn: CGRect(
                    x: flareCenter.x - minSide * 0.43,
                    y: flareCenter.y - minSide * 0.24,
                    width: minSide * 0.86,
                    height: minSide * 0.48
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.48 + 0.30 * Double(breathEase)),
                        Color(red: 0.34, green: 0.90, blue: 1.0).opacity(0.38 + 0.20 * Double(breathEase)),
                        Color(red: 0.66, green: 0.48, blue: 1.0).opacity(0.24),
                        .clear,
                    ]),
                    center: flareCenter,
                    startRadius: 0,
                    endRadius: minSide * 0.43
                )
            )
            layerContext.fill(
                Path(ellipseIn: CGRect(
                    x: flareCenter.x - minSide * 0.24,
                    y: flareCenter.y - minSide * 0.31,
                    width: minSide * 0.48,
                    height: minSide * 0.62
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.30 + 0.20 * Double(breathEase)),
                        Color(red: 0.70, green: 0.56, blue: 1.0).opacity(0.25 + 0.11 * Double(breathEase)),
                        .clear,
                    ]),
                    center: flareCenter,
                    startRadius: 0,
                    endRadius: minSide * 0.31
                )
            )
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 13 + 3.5 * breathEase))
            for string in strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.auraOpacity)),
                    style: StrokeStyle(lineWidth: string.auraWidth * 1.35, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 3.3 + 1.6 * breathEase))
            for string in strings {
                layerContext.stroke(
                    string.path,
                    with: .color(string.color.opacity(string.bodyOpacity)),
                    style: StrokeStyle(lineWidth: string.bodyWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 0.18))
            for string in strings where string.isFrontCore {
                layerContext.stroke(
                    string.path.trimmedPath(from: 0.045, to: 0.955),
                    with: .color(string.color.opacity(string.coreOpacity)),
                    style: StrokeStyle(lineWidth: string.coreWidth, lineCap: .round, lineJoin: .round)
                )
                layerContext.stroke(
                    string.path.trimmedPath(from: 0, to: 0.055),
                    with: .color(string.color.opacity(string.coreOpacity * 0.20)),
                    style: StrokeStyle(lineWidth: string.coreWidth * 0.78, lineCap: .round, lineJoin: .round)
                )
                layerContext.stroke(
                    string.path.trimmedPath(from: 0.945, to: 1),
                    with: .color(string.color.opacity(string.coreOpacity * 0.20)),
                    style: StrokeStyle(lineWidth: string.coreWidth * 0.78, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 0.42))
            for string in strings where string.isFrontCore {
                layerContext.stroke(
                    string.path.trimmedPath(from: 0.20, to: 0.78),
                    with: .color(Color.white.opacity(string.coreOpacity * 0.72)),
                    style: StrokeStyle(lineWidth: max(1.0, string.coreWidth * 0.92), lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 2.2))
            for string in strings where string.isFrontCore {
                let start = max(0.06, string.pulsePosition - string.pulseWidth)
                let end = min(0.94, string.pulsePosition + string.pulseWidth)
                guard end > start else {
                    continue
                }

                layerContext.stroke(
                    string.path.trimmedPath(from: start, to: end),
                    with: .color(string.color.opacity(string.pulseOpacity * 0.58)),
                    style: StrokeStyle(lineWidth: max(3.2, string.bodyWidth * 1.34), lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 0.32))
            for string in strings where string.isFrontCore {
                let start = max(0.06, string.pulsePosition - string.pulseWidth * 0.50)
                let end = min(0.94, string.pulsePosition + string.pulseWidth * 0.50)
                guard end > start else {
                    continue
                }

                layerContext.stroke(
                    string.path.trimmedPath(from: start, to: end),
                    with: .color(Color(red: 0.92, green: 0.98, blue: 1.0).opacity(string.pulseOpacity)),
                    style: StrokeStyle(lineWidth: max(0.8, string.coreWidth * 1.18), lineCap: .round, lineJoin: .round)
                )
            }
        }

        drawSilkRibbonKnotLacing(
            in: &context,
            size: size,
            center: flareCenter,
            breath: breathEase,
            flow: reversibleFlow,
            time: ribbonTime,
            reduceMotion: reduceMotion
        )

        drawSilkRibbonHotKnot(
            in: &context,
            size: size,
            center: flareCenter,
            breath: breathEase,
            flow: reversibleFlow,
            time: ribbonTime
        )
    }

    private static func drawSilkRibbonSheets(
        in context: inout GraphicsContext,
        size: CGSize,
        breath: CGFloat,
        flow: CGFloat,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let minSide = min(width, height)
        let sheetCount = reduceMotion ? 2 : 5
        let samples = reduceMotion ? 22 : 30
        let t = CGFloat(time)

        func sheetPath(index: Int) -> Path {
            let seed = index * 97 + 6101
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 17)
            let n2 = pseudoNoise(seed + 31)
            let phase = flow * (.pi * (0.78 + 0.20 * n0)) + t * (0.010 + 0.006 * n1) + n2 * .pi * 2
            var upper: [CGPoint] = []
            var lower: [CGPoint] = []

            for sample in 0...samples {
                let u = CGFloat(sample) / CGFloat(samples)
                let edge = pow(max(0, sin(u * .pi)), 0.42)
                let knot = exp(-pow((u - 0.52) / 0.23, 2))
                let centerX = width * (-0.12 + 1.24 * u)
                let centerY = height * (
                    0.606
                    - 0.228 * u
                    + 0.030 * edge * sin(.pi * 2 * (u * 1.16 + 0.10 * CGFloat(index)) + phase)
                    + 0.014 * edge * sin(.pi * 2 * (u * 2.75 + n1) - phase * 0.62)
                )
                let halfHeight = minSide * (0.021 + 0.046 * knot + 0.012 * n0) * (0.90 + 0.28 * breath)
                let edgeRipple = minSide * 0.008 * edge * sin(.pi * 2 * (u * 3.4 + n2) + phase)
                let skew = width * 0.010 * edge * (CGFloat(index) - CGFloat(sheetCount - 1) * 0.5)

                upper.append(CGPoint(x: centerX + skew, y: centerY - halfHeight + edgeRipple))
                lower.append(CGPoint(x: centerX - skew * 0.6, y: centerY + halfHeight - edgeRipple * 0.8))
            }

            var path = Path()
            if let first = upper.first {
                path.move(to: first)
                for point in upper.dropFirst() {
                    path.addLine(to: point)
                }
                for point in lower.reversed() {
                    path.addLine(to: point)
                }
                path.closeSubpath()
            }
            return path
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))

            for index in 0..<sheetCount {
                let seed = index * 67 + 7103
                let n0 = pseudoNoise(seed)
                let cyan = Color(red: 0.32, green: 0.86, blue: 1.0)
                let violet = Color(red: 0.64, green: 0.46, blue: 1.0)
                let color = index.isMultiple(of: 2) ? cyan : violet
                let opacity = (0.126 + 0.048 * Double(n0)) * Double(0.86 + 0.36 * breath)

                layer.fill(sheetPath(index: index), with: .color(color.opacity(opacity)))
            }
        }
    }

    private static func drawSilkRibbonHotKnot(
        in context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        breath: CGFloat,
        flow: CGFloat,
        time: TimeInterval
    ) {
        let minSide = min(size.width, size.height)
        let t = CGFloat(time)
        let rotation: CGFloat = -0.31
        let cosine = cos(rotation)
        let sine = sin(rotation)

        func localPoint(x: CGFloat, y: CGFloat) -> CGPoint {
            CGPoint(
                x: center.x + x * cosine - y * sine,
                y: center.y + x * sine + y * cosine
            )
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 4.8))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - minSide * 0.145,
                    y: center.y - minSide * 0.070,
                    width: minSide * 0.290,
                    height: minSide * 0.140
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.78 + 0.38 * Double(breath)),
                        Color(red: 0.66, green: 1.0, blue: 1.0).opacity(0.54 + 0.23 * Double(breath)),
                        Color(red: 0.80, green: 0.60, blue: 1.0).opacity(0.27 + 0.13 * Double(breath)),
                        .clear,
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: minSide * 0.145
                )
            )
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.34))

            for index in 0..<10 {
                let seed = index * 53 + 8501
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 13)
                let n2 = pseudoNoise(seed + 29)
                let lane = (CGFloat(index) - 4.5) / 4.5
                let crossingSign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                let phase = flow * (.pi * (1.05 + 0.22 * n0)) + t * (0.015 + 0.010 * n1) + n2 * .pi * 2
                let length = minSide * (0.135 + 0.030 * n0)
                let laneOffset = lane * minSide * 0.020 + minSide * (n1 - 0.5) * 0.010
                var points: [CGPoint] = []

                for sample in 0...14 {
                    let u = CGFloat(sample) / 14
                    let centered = u * 2 - 1
                    let envelope = pow(max(0, sin(u * .pi)), 0.52)
                    let x = centered * length
                    let braid = crossingSign * minSide * 0.042 * centered * envelope
                    let ripple = minSide * 0.010 * envelope * sin(u * .pi * 3.0 + phase)
                    let micro = minSide * 0.0045 * sin(u * .pi * 7.0 - phase * 0.7 + CGFloat(index))
                    points.append(localPoint(x: x, y: laneOffset + braid + ripple + micro))
                }

                let color = index.isMultiple(of: 3)
                    ? Color.white
                    : (index.isMultiple(of: 2) ? Color(red: 0.66, green: 0.96, blue: 1.0) : Color(red: 0.86, green: 0.68, blue: 1.0))
                let opacity = (0.62 + 0.30 * Double(breath)) * Double(0.74 + 0.26 * n2)

                layer.stroke(
                    smoothPath(through: points),
                    with: .color(color.opacity(opacity)),
                    style: StrokeStyle(lineWidth: 0.80 + 1.02 * n1, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.62))

            for index in 0..<3 {
                let lane = CGFloat(index - 1)
                let phase = flow * (.pi * (0.92 + 0.12 * CGFloat(index))) + t * (0.010 + 0.004 * CGFloat(index))
                let length = minSide * (0.088 + 0.014 * CGFloat(index))
                let y = lane * minSide * 0.009
                let points = [
                    localPoint(x: -length, y: y + minSide * 0.005 * sin(phase)),
                    localPoint(x: -length * 0.34, y: y - minSide * 0.010 * cos(phase * 0.8)),
                    localPoint(x: length * 0.28, y: y + minSide * 0.008 * sin(phase * 1.2)),
                    localPoint(x: length, y: y - minSide * 0.004 * cos(phase)),
                ]
                let color = index == 1
                    ? Color.white
                    : Color(red: 0.76, green: 0.98, blue: 1.0)

                layer.stroke(
                    smoothPath(through: points),
                    with: .color(color.opacity(0.62 + 0.30 * Double(breath))),
                    style: StrokeStyle(lineWidth: 0.96 + 0.36 * CGFloat(index), lineCap: .round, lineJoin: .round)
                )
            }
        }

        for index in 0..<4 {
            let lane = CGFloat(index) - 1.5
            let crossingSign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let phase = flow * (.pi * (0.74 + 0.10 * CGFloat(index))) + t * (0.010 + 0.004 * CGFloat(index))
            let length = minSide * (0.074 + 0.008 * CGFloat(index))
            let points = [
                localPoint(x: -length, y: lane * minSide * 0.006 + crossingSign * minSide * 0.010 * sin(phase)),
                localPoint(x: -length * 0.28, y: lane * minSide * 0.003 - crossingSign * minSide * 0.014 * cos(phase * 0.8)),
                localPoint(x: length * 0.26, y: -lane * minSide * 0.003 + crossingSign * minSide * 0.012 * sin(phase * 1.1)),
                localPoint(x: length, y: -lane * minSide * 0.006 - crossingSign * minSide * 0.008 * cos(phase)),
            ]
            let color = index == 1
                ? Color.white
                : Color(red: 0.78, green: 0.98, blue: 1.0)

            context.stroke(
                smoothPath(through: points),
                with: .color(color.opacity(0.58 + 0.28 * Double(breath))),
                style: StrokeStyle(lineWidth: 0.54 + 0.15 * CGFloat(index), lineCap: .round, lineJoin: .round)
            )
        }

    }

    private static func drawSilkRibbonKnotLacing(
        in context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        breath: CGFloat,
        flow: CGFloat,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let minSide = min(size.width, size.height)
        let t = CGFloat(time)
        let laces = reduceMotion ? 3 : 3
        let samples = reduceMotion ? 28 : 32
        let rotation: CGFloat = -0.31
        let cosine = cos(rotation)
        let sine = sin(rotation)

        func transformedPoint(localX: CGFloat, localY: CGFloat) -> CGPoint {
            CGPoint(
                x: center.x + localX * cosine - localY * sine,
                y: center.y + localX * sine + localY * cosine
            )
        }

        func lacePath(index: Int, scale: CGFloat) -> Path {
            let seed = index * 89 + 4703
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 17)
            let phase = flow * (.pi * 1.86 + 0.60 * n0) + t * (0.018 + 0.010 * n0) + n1 * .pi * 2
            let width = minSide * (0.145 + 0.030 * n0) * scale
            let height = minSide * (0.034 + 0.020 * n1) * scale
            var points: [CGPoint] = []

            for sample in 0...samples {
                let u = CGFloat(sample) / CGFloat(samples)
                let a = -CGFloat.pi + u * .pi * 2
                let taper = pow(max(0, sin(u * .pi)), 0.38)
                let x = width * sin(a)
                let y = height * sin(2 * a + phase + CGFloat(index) * 0.62)
                    + minSide * 0.010 * taper * sin(3 * a - phase * 0.5)
                points.append(transformedPoint(localX: x, localY: y))
            }

            return smoothPath(through: points)
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 9.0))

            for index in 0..<laces {
                let path = lacePath(index: index, scale: 1.18 + 0.10 * pseudoNoise(index * 17 + 3))
                let color = index.isMultiple(of: 2)
                    ? Color(red: 0.32, green: 0.90, blue: 1.0)
                    : Color(red: 0.70, green: 0.50, blue: 1.0)

                layer.stroke(
                    path,
                    with: .color(color.opacity((0.060 + 0.030 * Double(breath)) * Double(0.72 + 0.28 * pseudoNoise(index * 31 + 11)))),
                    style: StrokeStyle(lineWidth: minSide * (0.025 + 0.010 * pseudoNoise(index * 41 + 19)), lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.2))

            for index in 0..<laces {
                let path = lacePath(index: index, scale: 1.0)
                let color = index.isMultiple(of: 2)
                    ? Color(red: 0.72, green: 0.98, blue: 1.0)
                    : Color(red: 0.86, green: 0.72, blue: 1.0)

                layer.stroke(
                    path.trimmedPath(from: 0.08, to: 0.92),
                    with: .color(color.opacity(0.38 + 0.28 * Double(breath))),
                    style: StrokeStyle(lineWidth: max(0.9, minSide * (0.0026 + 0.0012 * pseudoNoise(index * 47 + 23))), lineCap: .round, lineJoin: .round)
                )
            }
        }

    }

    private static func drawSilkRibbonVeils(
        in context: inout GraphicsContext,
        size: CGSize,
        breath: CGFloat,
        cyclePhase: CGFloat,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let minSide = min(width, height)
        let count = reduceMotion ? 4 : 6
        let intensity = 0.86 + 0.52 * breath

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 17))

            for index in 0..<count {
                let path = silkRibbonVeilPath(
                    index: index,
                    count: count,
                    width: width,
                    height: height,
                    breath: breath,
                    cyclePhase: cyclePhase,
                    time: CGFloat(time)
                )
                let seed = index * 101 + 337
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 17)
                let color = silkRibbonVeilColor(index: index, breath: breath)
                let lineWidth = minSide * (0.056 + 0.034 * n0) * (0.92 + 0.30 * breath)
                let opacity = Double(0.070 + 0.038 * n1) * Double(intensity)

                layer.stroke(
                    path,
                    with: .color(color.opacity(opacity)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.8))

            for index in 0..<count {
                let path = silkRibbonVeilPath(
                    index: index,
                    count: count,
                    width: width,
                    height: height,
                    breath: breath,
                    cyclePhase: cyclePhase,
                    time: CGFloat(time)
                )
                let centerDistance = abs(CGFloat(index) - CGFloat(count - 1) * 0.5) / max(1, CGFloat(count - 1) * 0.5)
                let lineWidth = max(0.8, minSide * (0.0022 + 0.0028 * (1 - centerDistance)))
                let opacity = Double(0.34 + 0.36 * (1 - centerDistance)) * Double(0.86 + 0.34 * breath)
                let color = centerDistance < 0.25
                    ? Color(red: 0.92, green: 0.98, blue: 1.0)
                    : silkRibbonVeilColor(index: index, breath: breath)

                layer.stroke(
                    path.trimmedPath(from: 0.035, to: 0.965),
                    with: .color(color.opacity(opacity)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }

        let flareCenter = CGPoint(
            x: width * (0.535 + 0.010 * sin(cyclePhase + CGFloat(time) * 0.05)),
            y: height * (0.482 - 0.020 * breath)
        )

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 13))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: flareCenter.x - minSide * 0.23,
                    y: flareCenter.y - minSide * 0.125,
                    width: minSide * 0.46,
                    height: minSide * 0.25
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.42 + 0.28 * Double(breath)),
                        Color(red: 0.30, green: 0.86, blue: 1.0).opacity(0.28),
                        Color(red: 0.66, green: 0.46, blue: 1.0).opacity(0.15),
                        .clear,
                    ]),
                    center: flareCenter,
                    startRadius: 0,
                    endRadius: minSide * 0.23
                )
            )
        }
    }

    private static func silkRibbonVeilPath(
        index: Int,
        count: Int,
        width: CGFloat,
        height: CGFloat,
        breath: CGFloat,
        cyclePhase: CGFloat,
        time: CGFloat
    ) -> Path {
        let seed = index * 113 + 577
        let n0 = pseudoNoise(seed)
        let n1 = pseudoNoise(seed + 13)
        let n2 = pseudoNoise(seed + 31)
        let n3 = pseudoNoise(seed + 53)
        let centerIndex = CGFloat(count - 1) * 0.5
        let lane = (CGFloat(index) - centerIndex) / max(1, centerIndex)
        let phase = time * (0.026 + 0.020 * n1) + n2 * .pi * 2
        let counterPhase = time * (0.018 + 0.016 * n0) + n3 * .pi * 2
        let spread = 0.74 + 0.46 * breath
        let start = CGPoint(
            x: width * (-0.09 - 0.018 * n0),
            y: height * (0.602 + lane * 0.104 * spread + 0.024 * sin(phase))
        )
        let knot = CGPoint(
            x: width * (0.535 + 0.026 * sin(counterPhase + cyclePhase)),
            y: height * (0.482 + lane * 0.013 + 0.023 * cos(phase * 0.9 + cyclePhase))
        )
        let end = CGPoint(
            x: width * (1.08 + 0.020 * n3),
            y: height * (0.368 - lane * 0.094 * spread + 0.027 * cos(phase * 0.86))
        )
        let control1 = CGPoint(
            x: width * (0.16 + 0.026 * sin(phase + lane)),
            y: height * (0.668 + lane * 0.050 - 0.030 * breath + 0.028 * cos(counterPhase))
        )
        let control2 = CGPoint(
            x: width * (0.35 + 0.030 * cos(counterPhase + lane)),
            y: height * (0.352 - lane * 0.082 + 0.045 * breath + 0.030 * sin(phase))
        )
        let control3 = CGPoint(
            x: width * (0.65 + 0.030 * sin(counterPhase * 0.9)),
            y: height * (0.610 - lane * 0.112 + 0.025 * sin(phase + 1.1))
        )
        let control4 = CGPoint(
            x: width * (0.84 + 0.028 * cos(phase * 0.8)),
            y: height * (0.304 - lane * 0.052 + 0.035 * breath + 0.025 * cos(counterPhase + 0.7))
        )

        var path = Path()
        path.move(to: start)
        path.addCurve(to: knot, control1: control1, control2: control2)
        path.addCurve(to: end, control1: control3, control2: control4)
        return path
    }

    private static func silkRibbonVeilColor(index: Int, breath: CGFloat) -> Color {
        let palette: [(red: Double, green: Double, blue: Double)] = [
            (0.20, 0.76, 1.00),
            (0.28, 0.88, 1.00),
            (0.48, 0.56, 1.00),
            (0.66, 0.46, 1.00),
            (0.80, 0.56, 1.00),
        ]
        let base = palette[index % palette.count]
        let warm = min(0.14, 0.025 + 0.12 * Double(breath))
        return Color(
            red: base.red + (0.98 - base.red) * warm,
            green: base.green + (0.48 - base.green) * warm,
            blue: base.blue + (0.90 - base.blue) * warm
        )
    }

    private static func drawSilkRibbonDustFields(
        in context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        breath: CGFloat,
        flow: CGFloat,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let minSide = min(width, height)
        let t = CGFloat(time)
        let count = reduceMotion ? 86 : 240
        let diagonal = CGVector(dx: cos(-0.30), dy: sin(-0.30))
        let pulse = 0.82 + 0.18 * sin(t * 0.42 + flow * .pi * 3.0)
        var cyanDust = Path()
        var violetDust = Path()
        var whiteDust = Path()
        var sparkLines = Path()

        for index in 0..<count {
            let seed = index * 73 + 9301
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 13)
            let n2 = pseudoNoise(seed + 31)
            let n3 = pseudoNoise(seed + 59)
            let n4 = pseudoNoise(seed + 83)
            let radial = pow(n1, 1.58)
            let centrality = max(0, 1 - radial)
            let angle = n0 * .pi * 2
            let distance = minSide * (0.010 + 0.360 * radial) * (0.88 + 0.30 * breath)
            let ribbonProgress = n4
            let ribbonX = width * (-0.05 + 1.10 * ribbonProgress)
            let ribbonY = height * (0.620 - 0.250 * ribbonProgress)
                + minSide * 0.060 * sin(ribbonProgress * .pi * 2.0 + flow * .pi * 2.0 + n2 * .pi)
            let cloudX = center.x
                + cos(angle) * distance * (1.44 + 0.34 * n2)
                + diagonal.dx * minSide * 0.040 * sin(flow * .pi * 2.2 + n3 * .pi * 2)
            let cloudY = center.y
                + sin(angle) * distance * (0.45 + 0.28 * n3)
                + diagonal.dy * minSide * 0.030 * cos(flow * .pi * 1.8 + n2 * .pi * 2)
            let ribbonBlend = n3 > 0.72 ? 0.48 : 0.16
            let x = cloudX + (ribbonX - cloudX) * ribbonBlend
            let y = cloudY + (ribbonY - cloudY) * ribbonBlend
            let radius = (0.28 + 0.82 * n2) * (0.64 + 0.76 * centrality)
            let rect = CGRect(
                x: x - radius * (0.70 + 0.30 * n1),
                y: y - radius * (0.70 + 0.30 * n0),
                width: radius * (1.15 + 0.72 * n3),
                height: radius * (1.10 + 0.58 * n4)
            )

            if n4 > 0.88 || centrality > 0.78 {
                whiteDust.addRect(rect)
            } else if n2 > 0.50 {
                cyanDust.addRect(rect)
            } else {
                violetDust.addRect(rect)
            }

            if n3 > 0.58 && centrality > 0.22 {
                let lineAngle = -0.30 + (n2 - 0.5) * 0.85
                let halfLength = (0.7 + 2.5 * n0) * (0.62 + 0.82 * centrality)
                sparkLines.move(to: CGPoint(
                    x: x - cos(lineAngle) * halfLength,
                    y: y - sin(lineAngle) * halfLength
                ))
                sparkLines.addLine(to: CGPoint(
                    x: x + cos(lineAngle) * halfLength,
                    y: y + sin(lineAngle) * halfLength
                ))
            }
        }

        context.fill(
            violetDust,
            with: .color(Color(red: 0.76, green: 0.52, blue: 1.0).opacity(0.092 * Double(pulse) * Double(0.90 + 0.36 * breath)))
        )
        context.fill(
            cyanDust,
            with: .color(Color(red: 0.36, green: 0.88, blue: 1.0).opacity(0.104 * Double(pulse) * Double(0.90 + 0.36 * breath)))
        )
        context.fill(
            whiteDust,
            with: .color(Color.white.opacity(0.150 * Double(pulse) * Double(0.84 + 0.38 * breath)))
        )
        context.stroke(
            sparkLines,
            with: .color(Color(red: 0.88, green: 0.98, blue: 1.0).opacity(0.34 * Double(pulse))),
            style: StrokeStyle(lineWidth: 0.74, lineCap: .round, lineJoin: .round)
        )
    }

    private static func drawSilkRibbonSparkBurst(
        in context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        breath: CGFloat,
        flow: CGFloat,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let minSide = min(width, height)
        let count = reduceMotion ? 18 : 42
        let t = CGFloat(time)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.45))

            for index in 0..<count {
                let seed = index * 71 + 2401
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 11)
                let n2 = pseudoNoise(seed + 23)
                let n3 = pseudoNoise(seed + 47)
                let angle = n0 * .pi * 2
                let distance = minSide * (0.010 + 0.360 * pow(n1, 1.70)) * (0.84 + 0.30 * breath)
                let localFlow = flow * (.pi * 1.60 + 0.74 * n2) + t * (0.012 + 0.010 * n2) + n3 * .pi * 2
                let diagonal = CGVector(dx: cos(-0.30), dy: sin(-0.30))
                let spreadX = cos(angle) * distance * (1.48 + 0.35 * n2)
                    + diagonal.dx * minSide * 0.070 * sin(localFlow)
                let spreadY = sin(angle) * distance * (0.46 + 0.34 * n3)
                    + diagonal.dy * minSide * 0.054 * cos(localFlow * 0.9)
                let x = center.x + spreadX
                let y = center.y + spreadY
                let radius = 0.13 + 0.54 * n2
                let local = max(0, 1 - distance / max(1, minSide * 0.34))
                let twinkle = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * (0.42 + 0.55 * n3) + n2 * .pi * 2))
                let opacity = Double(0.160 + 0.64 * local) * Double(0.84 + 0.46 * breath) * Double(twinkle)
                let color: Color

                if n3 > 0.78 {
                    color = Color.white.opacity(opacity * 1.25)
                } else if n2 > 0.48 {
                    color = Color(red: 0.35, green: 0.86, blue: 1.0).opacity(opacity)
                } else {
                    color = Color(red: 0.92, green: 0.36, blue: 1.0).opacity(opacity * 0.82)
                }

                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * (1.3 + 0.9 * n1),
                        height: radius * (1.1 + 0.7 * n0)
                    )),
                    with: .color(color)
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
        let cyclePhase = CGFloat(snapshot.angle)
        let cycleBreath = 0.5 - 0.5 * cos(cyclePhase)
        let skyBreath = CGFloat(BreathingTimeline.smoothstep(Double(cycleBreath)))
        let breath = skyBreath * motionScale
        let phaseEase = CGFloat(BreathingTimeline.smoothstep(snapshot.phaseProgress))
        let inhaleBrightness = snapshot.isInhale ? phaseEase : max(0, 1 - phaseEase)
        let exhaleWave = max(0, -sin(cyclePhase))
        let exhaleDarkening = CGFloat(BreathingTimeline.smoothstep(Double(exhaleWave)))
        let sunBrightness = min(1.72, max(0.82, 1.00 + 0.64 * inhaleBrightness + 0.18 * skyBreath - 0.16 * exhaleDarkening))
        let sunBrightnessDouble = Double(sunBrightness)
        let sunRise = pow(skyBreath, 1.15)
        let horizonY = height * 0.60
        let cameraWobble = CGFloat(sin(time * 0.17) * 1.4 + cos(time * 0.11) * 0.9) * motionScale
        let baseSunRadius = min(width, height) * 0.184
        let sunRadius = baseSunRadius * (0.975 + 0.05 * breath)
        let sunVerticalOffset = baseSunRadius * (0.43 - 0.67 * sunRise)
        let sunCenter = CGPoint(
            x: width * (0.5 + 0.012 * sin(CGFloat(time) * 0.08)),
            y: horizonY + cameraWobble + sunVerticalOffset
        )

        var sky = Path()
        sky.addRect(CGRect(x: 0, y: 0, width: width, height: horizonY))
        context.fill(
            sky,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.035 + 0.030 * Double(skyBreath), green: 0.048 + 0.032 * Double(skyBreath), blue: 0.165 + 0.135 * Double(skyBreath)),
                    Color(red: 0.092 + 0.095 * Double(skyBreath), green: 0.076 + 0.054 * Double(skyBreath), blue: 0.250 + 0.132 * Double(skyBreath)),
                    Color(red: 0.290 + 0.175 * Double(skyBreath), green: 0.145 + 0.078 * Double(skyBreath), blue: 0.360 + 0.078 * Double(skyBreath)),
                    Color(red: 0.650 + 0.260 * Double(skyBreath), green: 0.250 + 0.170 * Double(skyBreath), blue: 0.330 + 0.036 * Double(skyBreath)),
                    Color(red: 1.000, green: 0.365 + 0.175 * Double(skyBreath), blue: 0.245 + 0.045 * Double(skyBreath)),
                ]),
                startPoint: CGPoint(x: width * 0.2, y: 0),
                endPoint: CGPoint(x: width * 0.58, y: horizonY)
            )
        )

        context.fill(
            sky,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.006, green: 0.010, blue: 0.050).opacity(0.38 * Double(exhaleDarkening)),
                    Color(red: 0.020, green: 0.018, blue: 0.060).opacity(0.24 * Double(exhaleDarkening)),
                    Color(red: 0.060, green: 0.026, blue: 0.070).opacity(0.13 * Double(exhaleDarkening)),
                ]),
                startPoint: CGPoint(x: width * 0.45, y: 0),
                endPoint: CGPoint(x: width * 0.55, y: horizonY)
            )
        )

        context.fill(
            sky,
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.360, blue: 0.240).opacity(0.20 + 0.20 * Double(skyBreath)),
                    Color(red: 0.88, green: 0.120, blue: 0.280).opacity(0.085 + 0.08 * Double(skyBreath)),
                    .clear,
                ]),
                center: CGPoint(x: sunCenter.x, y: horizonY * 0.96),
                startRadius: sunRadius * 0.35,
                endRadius: max(width, height) * 0.54
            )
        )

        drawSunsetCloudWisps(
            in: &context,
            size: size,
            horizonY: horizonY,
            breath: skyBreath,
            time: time
        )

        context.fill(
            Path(ellipseIn: CGRect(
                x: sunCenter.x - sunRadius * 4.8,
                y: sunCenter.y - sunRadius * 4.5,
                width: sunRadius * 9.6,
                height: sunRadius * 8.8
            )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.82, blue: 0.48).opacity((0.42 + 0.22 * Double(sunRise)) * sunBrightnessDouble),
                        Color(red: 1.0, green: 0.48, blue: 0.32).opacity((0.20 + 0.12 * Double(sunRise)) * sunBrightnessDouble),
                        Color(red: 0.74, green: 0.20, blue: 0.34).opacity((0.060 + 0.045 * Double(sunRise)) * sunBrightnessDouble),
                        .clear,
                    ]),
                center: sunCenter,
                startRadius: sunRadius * 0.2,
                endRadius: sunRadius * 4.8
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
                        Color(red: 1.0, green: 0.94, blue: 0.58).opacity((0.24 + 0.26 * Double(sunRise)) * sunBrightnessDouble),
                        Color(red: 1.0, green: 0.78, blue: 0.43).opacity((0.54 + 0.24 * Double(sunRise)) * sunBrightnessDouble),
                        Color(red: 0.98, green: 0.48, blue: 0.32).opacity((0.22 + 0.10 * Double(sunRise)) * sunBrightnessDouble),
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
                    Color(red: 1.0, green: min(1.0, 1.00 + 0.02 * Double(sunRise) + 0.034 * Double(inhaleBrightness)), blue: 0.70 + 0.050 * Double(inhaleBrightness)),
                    Color(red: 1.0, green: min(1.0, 0.92 + 0.05 * Double(sunRise) + 0.060 * Double(inhaleBrightness)), blue: 0.53 + 0.040 * Double(inhaleBrightness)),
                    Color(red: 1.0, green: min(1.0, 0.74 + 0.06 * Double(sunRise) + 0.052 * Double(inhaleBrightness)), blue: 0.40 + 0.026 * Double(inhaleBrightness)),
                    Color(red: 1.0, green: min(1.0, 0.60 + 0.045 * Double(sunRise) + 0.038 * Double(inhaleBrightness)), blue: 0.34),
                ]),
                center: CGPoint(x: sunCenter.x, y: sunCenter.y - sunRadius * 0.08),
                startRadius: 0,
                endRadius: sunRadius
            )
        )

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.8))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: sunCenter.x - sunRadius * 0.92,
                    y: sunCenter.y - sunRadius * 0.92,
                    width: sunRadius * 1.84,
                    height: sunRadius * 1.84
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.140 + 0.400 * Double(inhaleBrightness)),
                        Color(red: 1.0, green: 0.86, blue: 0.40).opacity(0.160 + 0.300 * Double(inhaleBrightness)),
                        .clear,
                    ]),
                    center: CGPoint(x: sunCenter.x, y: sunCenter.y - sunRadius * 0.10),
                    startRadius: 0,
                    endRadius: sunRadius * 0.92
                )
            )
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.2))
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: sunCenter.x - sunRadius * 0.70,
                    y: sunCenter.y - sunRadius * 0.70,
                    width: sunRadius * 1.40,
                    height: sunRadius * 1.40
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.95, blue: 0.58).opacity((0.28 + 0.30 * Double(sunRise)) * sunBrightnessDouble),
                        Color(red: 1.0, green: 0.80, blue: 0.40).opacity((0.20 + 0.22 * Double(sunRise)) * sunBrightnessDouble),
                        .clear,
                    ]),
                    center: sunCenter,
                    startRadius: 0,
                    endRadius: sunRadius * 0.70
                )
            )
        }

        let waterTopY = horizonY
        var water = Path()
        water.addRect(CGRect(x: 0, y: waterTopY, width: width, height: height - waterTopY))
        let waterTopColor = Color(
            red: 0.148 + 0.044 * Double(breath),
            green: 0.108 + 0.034 * Double(breath),
            blue: 0.225 + 0.054 * Double(breath)
        )
        context.fill(
            water,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: waterTopColor.opacity(0.94), location: 0.0),
                    .init(color: waterTopColor, location: 0.085),
                    .init(color: Color(red: 0.090, green: 0.068, blue: 0.160), location: 0.48),
                    .init(color: Color(red: 0.044, green: 0.044, blue: 0.104), location: 1.0),
                ]),
                startPoint: CGPoint(x: width * 0.5, y: waterTopY),
                endPoint: CGPoint(x: width * 0.5, y: height)
            )
        )

        context.fill(
            water,
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.98, green: 0.370, blue: 0.230).opacity(0.19 + 0.18 * Double(breath)),
                    Color(red: 0.76, green: 0.180, blue: 0.230).opacity(0.12 + 0.10 * Double(breath)),
                    .clear,
                ]),
                center: CGPoint(x: sunCenter.x, y: horizonY + (height - horizonY) * 0.10),
                startRadius: 0,
                endRadius: width * (0.26 + 0.12 * breath)
            )
        )

        drawSunsetHorizonBlend(in: &context, size: size, horizonY: horizonY, breath: breath, time: time)
        drawOceanSurface(in: &context, size: size, horizonY: horizonY, breath: breath, time: time, sunCenterX: sunCenter.x)
        drawReflection(in: &context, size: size, horizonY: horizonY, breath: breath, time: time, sunCenterX: sunCenter.x)
    }

    private static func drawSunsetHorizonBlend(
        in context: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        breath: CGFloat,
        time: TimeInterval
    ) {
        let width = size.width
        let height = size.height
        let t = CGFloat(time)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 7.5))
            layer.fill(
                Path(CGRect(x: -width * 0.02, y: horizonY - height * 0.018, width: width * 1.04, height: height * 0.050)),
                with: .linearGradient(
                    Gradient(colors: [
                        .clear,
                        Color(red: 1.0, green: 0.62, blue: 0.34).opacity(0.120 + 0.078 * Double(breath)),
                        Color(red: 0.95, green: 0.36, blue: 0.30).opacity(0.062 + 0.040 * Double(breath)),
                        .clear,
                    ]),
                    startPoint: CGPoint(x: width * 0.5, y: horizonY - height * 0.018),
                    endPoint: CGPoint(x: width * 0.5, y: horizonY + height * 0.035)
                )
            )
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.9))

            for index in 0..<22 {
                let seed = index * 37 + 1601
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 11)
                let n2 = pseudoNoise(seed + 23)
                let y = horizonY + height * (-0.004 + 0.018 * n0)
                let centrality = pow(1 - abs(n1 - 0.5) * 2, 0.65)
                let length = width * (0.028 + 0.080 * n2) * (0.70 + 0.55 * centrality)
                let centerX = width * (0.5 + (n1 - 0.5) * 0.86)
                let phase = t * (0.045 + 0.045 * n2) + n0 * .pi * 2
                let path = sunsetGlintPath(
                    startX: centerX - length,
                    endX: centerX + length,
                    y: y,
                    amplitude: 0.25 + 0.70 * n2,
                    phase: phase,
                    segments: 2
                )
                let opacity = (0.016 + 0.026 * Double(breath)) * Double(0.35 + 0.65 * n0) * Double(0.58 + 0.42 * centrality)

                layer.stroke(
                    path,
                    with: .color(Color(red: 0.90, green: 0.34, blue: 0.28).opacity(opacity)),
                    style: StrokeStyle(lineWidth: 0.55 + 0.85 * n2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private static func drawSunsetCloudWisps(
        in context: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        breath: CGFloat,
        time: TimeInterval
    ) {
        let width = size.width
        let t = CGFloat(time)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 2.2))

            for index in 0..<18 {
                let seed = index * 47 + 701
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 11)
                let n2 = pseudoNoise(seed + 23)
                let n3 = pseudoNoise(seed + 37)
                let verticalBand = n0 * n0
                let y = horizonY * (0.22 + 0.70 * verticalBand)
                    + horizonY * 0.006 * sin(t * (0.018 + 0.018 * n2) + n1 * .pi * 2)
                let startX = width * (-0.18 + 1.10 * n1)
                let length = width * (0.18 + 0.42 * n2)
                let amplitude = width * (0.0025 + 0.0045 * n3)
                let warmth = 1 - y / max(1, horizonY)
                let lowerGlow = 1 - abs(CGFloat(0.78) - y / max(1, horizonY)) / 0.78
                let opacity = (0.022 + 0.044 * Double(max(0, lowerGlow)) + 0.030 * Double(breath)) * Double(0.45 + n2)
                let color = index.isMultiple(of: 3)
                    ? Color(red: 1.0, green: 0.34 + 0.10 * Double(warmth), blue: 0.24).opacity(opacity)
                    : Color(red: 0.88, green: 0.18 + 0.08 * Double(warmth), blue: 0.36).opacity(opacity * 0.82)

                layer.stroke(
                    wavePath(
                        startX: startX,
                        endX: startX + length,
                        y: y,
                        amplitude: amplitude,
                        phase: t * (0.016 + 0.018 * n0) + n3 * .pi * 2,
                        segments: 3
                    ),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 0.8 + 2.4 * n2, lineCap: .round, lineJoin: .round)
                )
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5.0))

            for index in 0..<7 {
                let seed = index * 53 + 971
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 17)
                let y = horizonY * (0.70 + 0.22 * n0)
                let startX = width * (-0.12 + 0.92 * n1)
                let length = width * (0.30 + 0.46 * pseudoNoise(seed + 31))

                layer.stroke(
                    wavePath(
                        startX: startX,
                        endX: startX + length,
                        y: y,
                        amplitude: width * (0.003 + 0.004 * pseudoNoise(seed + 47)),
                        phase: t * 0.012 + n0 * .pi * 2,
                        segments: 4
                    ),
                    with: .color(Color(red: 1.0, green: 0.42, blue: 0.24).opacity(0.038 + 0.040 * Double(breath))),
                    style: StrokeStyle(lineWidth: 3.5 + 3.5 * pseudoNoise(seed + 61), lineCap: .round, lineJoin: .round)
                )
            }
        }
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
        let reach = scale * (0.32 + 0.34 * breath)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 22))

            for index in 0..<(reduceMotion ? 6 : 16) {
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
                let distance = reach * (0.10 + 0.58 * n0) * (0.78 + 0.38 * localBreath)
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
                let radius = scale * (0.22 + 0.18 * n1) * (0.90 + 0.36 * localBreath)
                let rect = CGRect(
                    x: cloudCenter.x - radius * (1.05 + n0),
                    y: cloudCenter.y - radius * (0.88 + 0.45 * n1),
                    width: radius * (1.9 + 1.2 * n0),
                    height: radius * (1.6 + 1.0 * n1)
                )
                let colors: [Color] = [
                    Color(red: 0.86, green: 0.70, blue: 1.0).opacity(0.28 + 0.15 * Double(localBreath)),
                    Color(red: 0.22, green: 0.66, blue: 1.0).opacity(0.17 + 0.12 * Double(localPulse)),
                    Color(red: 0.46, green: 0.21, blue: 0.88).opacity(0.15),
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

            for index in 0..<(reduceMotion ? 16 : 44) {
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
                let radius = scale * (0.058 + 0.112 * n1) * (0.86 + 0.56 * localBreath)
                let alpha = 0.17 + 0.18 * Double(localPulse) + 0.14 * Double(localBreath)
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
                    x: center.x - reach * 0.68,
                    y: center.y - reach * 0.54,
                    width: reach * 1.36,
                    height: reach * 1.06
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.23 + 0.14 * Double(fullBreath)),
                        Color(red: 0.74, green: 0.60, blue: 1.0).opacity(0.43 + 0.20 * Double(breath)),
                        Color(red: 0.20, green: 0.70, blue: 1.0).opacity(0.26),
                        .clear,
                    ]),
                    center: center,
                    startRadius: reach * 0.08,
                    endRadius: reach * 0.76
                )
            )
        }

        drawBloomStarfield(
            in: &context,
            size: size,
            center: center,
            breath: fullBreath,
            time: time,
            reduceMotion: reduceMotion
        )
    }

    private static func drawBloomStarfield(
        in context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        breath: CGFloat,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let scale = min(width, height)
        let t = CGFloat(time)
        let count = reduceMotion ? 140 : 440

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.16))

            for index in 0..<count {
                let seed = index * 79 + 811
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 17)
                let n2 = pseudoNoise(seed + 31)
                let n3 = pseudoNoise(seed + 53)
                let x = width * n0
                    + scale * 0.010 * sin(t * (0.020 + 0.030 * n2) + n3 * .pi * 2)
                let y = height * n1
                    + scale * 0.010 * cos(t * (0.018 + 0.028 * n0) + n2 * .pi * 2)
                let normalizedX = (x - center.x) / max(1, width * 0.48)
                let normalizedY = (y - center.y) / max(1, height * 0.46)
                let proximity = max(0, 1 - sqrt(normalizedX * normalizedX + normalizedY * normalizedY))
                let twinkle = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * (0.22 + 0.18 * n3) + n2 * .pi * 2))
                let bright = n3 > 0.90
                let radius = bright ? (0.44 + 0.90 * n2) : (0.18 + 0.52 * n2)
                let opacity = (bright ? 0.44 : 0.074)
                    * Double(0.30 + 0.95 * proximity)
                    * Double(0.72 + 0.40 * breath)
                    * Double(twinkle)
                let color = bright
                    ? Color.white.opacity(opacity)
                    : Color(red: 0.72 + 0.22 * Double(n2), green: 0.66 + 0.18 * Double(n3), blue: 1.0).opacity(opacity)

                layer.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color)
                )
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 7.0))

            for index in 0..<(reduceMotion ? 5 : 12) {
                let seed = index * 97 + 1201
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 23)
                let n2 = pseudoNoise(seed + 41)
                let localCenter = CGPoint(
                    x: width * (0.12 + 0.76 * n0),
                    y: height * (0.18 + 0.68 * n1)
                )
                let radius = scale * (0.026 + 0.046 * n2)
                let alpha = 0.034 + 0.030 * Double(breath)

                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: localCenter.x - radius,
                        y: localCenter.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.90, green: 0.62, blue: 1.0).opacity(alpha * 1.10),
                            Color(red: 0.35, green: 0.52, blue: 1.0).opacity(alpha * 0.62),
                            .clear,
                        ]),
                        center: localCenter,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }

        drawBloomPinStars(
            in: &context,
            size: size,
            center: center,
            breath: breath,
            time: time,
            reduceMotion: reduceMotion
        )
    }

    private static func drawBloomPinStars(
        in context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        breath: CGFloat,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let scale = min(width, height)
        let t = CGFloat(time)
        let count = reduceMotion ? 76 : 280

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.08))

            for index in 0..<count {
                let seed = index * 83 + 2609
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 17)
                let n2 = pseudoNoise(seed + 37)
                let n3 = pseudoNoise(seed + 59)
                let x = width * n0 + scale * 0.006 * sin(t * (0.018 + 0.032 * n2) + n3 * .pi * 2)
                let y = height * n1 + scale * 0.006 * cos(t * (0.016 + 0.030 * n0) + n2 * .pi * 2)
                let dx = (x - center.x) / max(1, width * 0.52)
                let dy = (y - center.y) / max(1, height * 0.50)
                let proximity = max(0, 1 - sqrt(dx * dx + dy * dy))
                let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.35 + 0.28 * n3) + n1 * .pi * 2))
                let radius = 0.12 + 0.44 * n2
                let warm = n3 > 0.84
                let opacity = Double(0.052 + 0.205 * proximity)
                    * Double(0.78 + 0.42 * breath)
                    * Double(twinkle)
                let color = warm
                    ? Color(red: 1.0, green: 0.72, blue: 0.96).opacity(opacity)
                    : Color(red: 0.74 + 0.22 * Double(n2), green: 0.70 + 0.20 * Double(n3), blue: 1.0).opacity(opacity)

                layer.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color)
                )
            }
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
        let fullBreath = CGFloat(snapshot.breathAmount)
        let breathEase = CGFloat(BreathingTimeline.smoothstep(snapshot.breathAmount))
        let exhaleDepth = CGFloat(BreathingTimeline.smoothstep(Double(1 - fullBreath)))
        let glowLevel = 0.66 + 0.52 * breathEase
        let breath = CGFloat(snapshot.breathAmount) * motionScale
        let t = CGFloat(time)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 76))
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
                    Color(red: 0.48, green: 0.58, blue: 0.98).opacity((0.15 + 0.070 * Double(breath)) * Double(glowLevel)),
                    Color(red: 0.39, green: 0.47, blue: 0.88).opacity((0.120 + 0.058 * Double(breath)) * Double(glowLevel)),
                    Color(red: 0.29, green: 0.36, blue: 0.72).opacity((0.092 + 0.046 * Double(breath)) * Double(glowLevel)),
                    Color(red: 0.20, green: 0.26, blue: 0.56).opacity((0.066 + 0.036 * Double(breath)) * Double(glowLevel)),
                    Color(red: 0.12, green: 0.17, blue: 0.40).opacity((0.040 + 0.024 * Double(breath)) * Double(glowLevel)),
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
                let opacity = (0.020 + 0.018 * Double(localPulse) + 0.022 * Double(breath)) * Double(glowLevel)

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

        drawSoftGlowVeilTexture(
            in: &context,
            size: size,
            breath: breathEase,
            exhaleDepth: exhaleDepth,
            time: time,
            reduceMotion: reduceMotion
        )

        context.fill(
            Path(CGRect(x: 0, y: 0, width: width, height: height)),
            with: .color(.black.opacity(0.26 * Double(exhaleDepth)))
        )

        drawSoftGlowGrain(
            in: &context,
            size: size,
            count: reduceMotion ? 700 : 1_900,
            alphaScale: (reduceMotion ? 1.05 : 1.75) * (1.0 + 0.42 * Double(exhaleDepth))
        )
    }

    private static func drawSoftGlowVeilTexture(
        in context: inout GraphicsContext,
        size: CGSize,
        breath: CGFloat,
        exhaleDepth: CGFloat,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let scale = min(width, height)
        let t = CGFloat(time)
        let count = reduceMotion ? 3 : 5

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 68))

            for index in 0..<count {
                let seed = index * 67 + 4201
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 19)
                let n2 = pseudoNoise(seed + 41)
                let drift = CGPoint(
                    x: width * 0.025 * sin(t * (0.028 + 0.020 * n2) + n0 * .pi * 2),
                    y: height * 0.020 * cos(t * (0.026 + 0.020 * n1) + n2 * .pi * 2)
                )
                let center = CGPoint(
                    x: width * (0.16 + 0.70 * n0) + drift.x,
                    y: height * (0.18 + 0.56 * n1) + drift.y
                )
                let radius = scale * (0.16 + 0.18 * n2) * (0.92 + 0.16 * breath)
                let opacity = (0.0038 + 0.0070 * Double(n1)) * Double(0.78 + 0.36 * breath) * Double(1.0 - 0.35 * exhaleDepth)
                let cool = Color(red: 0.38 + 0.12 * Double(n0), green: 0.46 + 0.12 * Double(n2), blue: 0.94)
                let violet = Color(red: 0.34 + 0.12 * Double(n2), green: 0.28, blue: 0.70 + 0.16 * Double(n1))

                fillRadialEllipse(
                    in: &layer,
                    rect: CGRect(
                        x: center.x - radius * (1.4 + 0.8 * n1),
                        y: center.y - radius * (1.1 + 0.6 * n2),
                        width: radius * (2.5 + 1.1 * n1),
                        height: radius * (2.0 + 1.0 * n2)
                    ),
                    center: center,
                    startRadius: 0,
                    endRadius: radius * 1.9,
                    colors: [
                        cool.opacity(opacity),
                        violet.opacity(opacity * 0.72),
                        .clear,
                    ]
                )
            }
        }
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
            let radius = 0.16 + 0.20 * n2
            let alpha = (0.0042 + 0.0088 * Double(pseudoNoise(index * 73 + 83))) * alphaScale
            let color = index.isMultiple(of: 2)
                ? Color.white.opacity(alpha)
                : Color.black.opacity(alpha * 0.50)

            context.fill(
                Path(CGRect(x: size.width * n0, y: size.height * n1, width: radius, height: radius)),
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
            layer.addFilter(.blur(radius: 1.35))
            drawBlurredSunsetReflection(
                in: &layer,
                width: width,
                waterHeight: waterHeight,
                horizonY: horizonY,
                breath: breath,
                time: t,
                sunCenterX: sunCenterX
            )
        }

        drawMoltenSunsetReflection(
            in: &context,
            width: width,
            waterHeight: waterHeight,
            horizonY: horizonY,
            breath: breath,
            time: t,
            sunCenterX: sunCenterX
        )

        drawGoldenSunsetReflectionLattice(
            in: &context,
            width: width,
            waterHeight: waterHeight,
            horizonY: horizonY,
            breath: breath,
            time: t,
            sunCenterX: sunCenterX
        )

        drawSharpSunsetReflection(
            in: &context,
            width: width,
            waterHeight: waterHeight,
            horizonY: horizonY,
            breath: breath,
            time: t,
            sunCenterX: sunCenterX
        )
    }

    private static func drawMoltenSunsetReflection(
        in context: inout GraphicsContext,
        width: CGFloat,
        waterHeight: CGFloat,
        horizonY: CGFloat,
        breath: CGFloat,
        time: CGFloat,
        sunCenterX: CGFloat
    ) {
        let count = 156
        let pi2 = CGFloat.pi * 2

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.1))

            for index in 0..<count {
                let seed = index * 53 + 3209
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 13)
                let n2 = pseudoNoise(seed + 29)
                let depth = (CGFloat(index) + 0.45 * n0) / CGFloat(count)
                let nearHorizon = max(0, 1 - depth)
                let midTrail = max(0, 1 - abs(depth - 0.37) / 0.46)
                let tailFade = max(0, 1 - max(0, depth - 0.72) / 0.28)
                let y = horizonY + waterHeight * (0.035 + 0.86 * depth)
                let columnHalf = width * (0.012 + 0.040 * nearHorizon + 0.052 * midTrail)
                let centerDrift = width * (0.006 + 0.014 * depth) * sin(time * (0.18 + 0.16 * n2) + n1 * pi2)
                let centerX = sunCenterX + centerDrift + (n0 - 0.5) * columnHalf * (0.34 + 0.28 * depth)
                let widthBase = width * (0.009 + 0.074 * nearHorizon + 0.038 * midTrail)
                let halfWidth = widthBase * (0.34 + 0.84 * n1) * (0.80 + 0.22 * sin(time * (0.30 + 0.26 * n0) + n2 * pi2))
                let flicker = glintFlicker(time: time, speed: 0.90 + 1.80 * n2, phase: n1 * pi2, floor: 0.20)
                let opacity = Double(0.072 + 0.270 * nearHorizon + 0.190 * midTrail)
                    * Double(0.86 + 0.74 * breath)
                    * Double(0.58 + 0.68 * n1)
                    * Double(flicker)
                    * Double(0.22 + 0.78 * tailFade)
                let color = depth < 0.24
                    ? Color(red: 1.0, green: 0.78, blue: 0.36).opacity(opacity)
                    : Color(red: 1.0, green: 0.28 + 0.26 * Double(nearHorizon), blue: 0.22).opacity(opacity * 0.92)
                let path = sunsetGlintPath(
                    startX: centerX - halfWidth,
                    endX: centerX + halfWidth,
                    y: y,
                    amplitude: 0.45 + 3.6 * depth * (0.45 + n2),
                    phase: n2 * pi2 + time * (0.10 + 0.14 * n0),
                    segments: n0 > 0.34 ? 4 : 3
                )

                layer.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 0.44 + 0.78 * nearHorizon + 0.34 * n0, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private static func drawGoldenSunsetReflectionLattice(
        in context: inout GraphicsContext,
        width: CGFloat,
        waterHeight: CGFloat,
        horizonY: CGFloat,
        breath: CGFloat,
        time: CGFloat,
        sunCenterX: CGFloat
    ) {
        let count = 86
        let pi2 = CGFloat.pi * 2

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.46))

            for index in 0..<count {
                let seed = index * 47 + 1559
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 13)
                let n2 = pseudoNoise(seed + 31)
                let n3 = pseudoNoise(seed + 47)
                let depth = (CGFloat(index) + 0.42 * n0) / CGFloat(count)
                let nearHorizon = max(0, 1 - depth)
                let midTrail = max(0, 1 - abs(depth - 0.34) / 0.43)
                let tailFade = max(0, 1 - max(0, depth - 0.76) / 0.24)
                let y = horizonY + waterHeight * (0.048 + 0.82 * depth)
                let columnHalf = width * (0.018 + 0.090 * nearHorizon + 0.062 * midTrail)
                let centerX = sunCenterX
                    + width * (0.004 + 0.008 * depth) * sin(time * (0.20 + 0.18 * n2) + n1 * pi2)
                    + (n0 - 0.5) * columnHalf * (0.62 + 0.42 * depth)
                let halfWidth = width
                    * (0.010 + 0.085 * nearHorizon + 0.048 * midTrail)
                    * (0.34 + 0.94 * n2)
                    * (0.88 + 0.18 * sin(time * (0.28 + 0.20 * n3) + n0 * pi2))
                let phase = n3 * pi2 + time * (0.12 + 0.18 * n1)
                let flicker = glintFlicker(time: time, speed: 0.72 + 1.46 * n2, phase: n0 * pi2, floor: 0.36)
                let opacity = Double(0.060 + 0.250 * nearHorizon + 0.220 * midTrail)
                    * Double(0.82 + 0.72 * breath)
                    * Double(0.52 + 0.74 * n1)
                    * Double(0.24 + 0.76 * tailFade)
                    * Double(flicker)
                let color = depth < 0.30
                    ? Color(red: 1.0, green: 0.80, blue: 0.40).opacity(opacity)
                    : Color(red: 1.0, green: 0.34 + 0.22 * Double(nearHorizon), blue: 0.25 + 0.08 * Double(n2)).opacity(opacity * 0.92)
                let path = sunsetGlintPath(
                    startX: centerX - halfWidth,
                    endX: centerX + halfWidth,
                    y: y,
                    amplitude: 0.55 + 3.4 * depth * (0.36 + n3),
                    phase: phase,
                    segments: n0 > 0.38 ? 4 : 3
                )

                layer.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 0.52 + 0.86 * nearHorizon + 0.40 * n0, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private static func drawBlurredSunsetReflection(
        in context: inout GraphicsContext,
        width: CGFloat,
        waterHeight: CGFloat,
        horizonY: CGFloat,
        breath: CGFloat,
        time: CGFloat,
        sunCenterX: CGFloat
    ) {
        let total = CGFloat(224)
        let pi2 = CGFloat.pi * 2

        for index in 0..<224 {
            let seed = index * 41 + 113
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 7)
            let n2 = pseudoNoise(seed + 17)
            let n3 = pseudoNoise(seed + 31)
            let depth = (CGFloat(index) + n0 * 0.45) / total
            let nearHorizon = max(0, 1 - depth)
            let midColumn = max(0, 1 - abs(depth - 0.22) / 0.42)
            let tailFade = max(0, 1 - max(0, depth - 0.70) / 0.30)
            let y = horizonY + 4 + depth * waterHeight * 0.84

            let columnBase = 0.016 + 0.118 * nearHorizon + 0.066 * midColumn
            let columnHalf = width * columnBase
            let driftPhase = time * (0.36 + 0.34 * n2) + n3 * pi2
            let drift = width * (0.003 + 0.007 * depth) * sin(driftPhase)
            let centerX = sunCenterX + (n1 - 0.5) * columnHalf * 1.18 + drift

            let glintBase = 0.009 + 0.064 * nearHorizon + 0.034 * midColumn
            let scalePhase = time * (0.52 + 0.58 * n1) + n2 * pi2
            let widthScale = 0.52 + 0.58 * (0.5 + 0.5 * sin(scalePhase))
            let halfWidth = width * glintBase * (0.30 + 0.92 * n2) * widthScale
            let shimmer = glintFlicker(time: time, speed: 1.10 + 1.95 * n0, phase: n3 * pi2, floor: 0.24)
            let opacityBase = 0.086 + 0.142 * Double(breath)
            let depthGain = 0.50 + 1.10 * nearHorizon + 0.82 * midColumn
            let noiseGain = 0.48 + 0.90 * n2
            let opacity = opacityBase * Double(depthGain) * Double(noiseGain) * Double(shimmer) * Double(0.20 + 0.80 * tailFade)

            let amplitude = 0.55 + 2.7 * depth * (0.45 + n1)
            let phase = n3 * pi2
            let path = sunsetGlintPath(
                startX: centerX - halfWidth,
                endX: centerX + halfWidth,
                y: y,
                amplitude: amplitude,
                phase: phase,
                segments: n2 > 0.58 ? 3 : 2
            )
            let green = 0.34 + 0.24 * Double(nearHorizon)
            let color = Color(red: 1.0, green: green, blue: 0.24).opacity(opacity)
            let style = StrokeStyle(
                lineWidth: 0.58 + 1.02 * nearHorizon + 0.42 * n0,
                lineCap: .round,
                lineJoin: .round
            )

            context.stroke(path, with: .color(color), style: style)
        }
    }

    private static func drawSharpSunsetReflection(
        in context: inout GraphicsContext,
        width: CGFloat,
        waterHeight: CGFloat,
        horizonY: CGFloat,
        breath: CGFloat,
        time: CGFloat,
        sunCenterX: CGFloat
    ) {
        let total = CGFloat(420)
        let pi2 = CGFloat.pi * 2

        for index in 0..<420 {
            let seed = index * 43 + 227
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 13)
            let n2 = pseudoNoise(seed + 29)
            let n3 = pseudoNoise(seed + 41)
            let depth = (CGFloat(index) + 0.5 * n0) / total
            let nearHorizon = max(0, 1 - depth)
            let midColumn = max(0, 1 - abs(depth - 0.25) / 0.48)
            let tailFade = max(0, 1 - max(0, depth - 0.70) / 0.30)
            let y = horizonY + 5 + depth * waterHeight * 0.90
            let columnBase = 0.016 + 0.124 * nearHorizon + 0.068 * midColumn
            let columnHalf = width * columnBase
            let rowPhase = time * (0.42 + 0.44 * n3) + n2 * pi2
            let rowDrift = width * (0.003 + 0.007 * depth) * sin(rowPhase)
            let centerX = sunCenterX + rowDrift + (n1 - 0.5) * columnHalf * 1.26
            let fragmentCount = n2 > 0.66 ? 3 : (n2 > 0.22 ? 2 : 1)

            for fragment in 0..<fragmentCount {
                let f = CGFloat(fragment)
                let fn0 = pseudoNoise(seed + fragment * 67 + 101)
                let fn1 = pseudoNoise(seed + fragment * 67 + 119)
                let offsetX = (fn0 - 0.5) * columnHalf * (0.24 + 0.28 * depth)
                let widthBase = 0.0045 + 0.040 * nearHorizon + 0.023 * midColumn
                let scalePhase = time * (0.70 + 0.72 * fn0) + fn1 * pi2 + f
                let widthScale = 0.45 + 0.68 * (0.5 + 0.5 * sin(scalePhase))
                let halfWidth = width * widthBase * (0.30 + 1.10 * fn1) * widthScale / CGFloat(fragmentCount)
                let phase = n3 * pi2 + f * 0.63
                let flicker = glintFlicker(time: time, speed: 1.25 + 2.40 * fn1, phase: fn0 * pi2 + f, floor: 0.115)
                let depthBrightness = 0.046 + 0.188 * Double(nearHorizon) + 0.116 * Double(midColumn)
                let breathBrightness = 0.86 + 0.78 * Double(breath)
                let noiseBrightness = 0.58 + 0.84 * Double(fn1)
                let brightness = depthBrightness * breathBrightness * noiseBrightness * Double(flicker) * Double(0.18 + 0.82 * tailFade)
                let color: Color

                if n3 > 0.78 && depth < 0.46 {
                    color = Color(red: 1.0, green: 0.84, blue: 0.52).opacity(brightness * 1.18)
                } else if depth < 0.34 {
                    color = Color(red: 1.0, green: 0.56 + 0.18 * Double(fn0), blue: 0.30).opacity(brightness)
                } else {
                    color = Color(red: 1.0, green: 0.23 + 0.12 * Double(fn0), blue: 0.24 + 0.08 * Double(fn1)).opacity(brightness * 0.78)
                }

                let path = sunsetGlintPath(
                    startX: centerX + offsetX - halfWidth,
                    endX: centerX + offsetX + halfWidth,
                    y: y + (fn1 - 0.5) * (1.0 + 2.6 * depth),
                    amplitude: 0.30 + 1.9 * depth * (0.45 + fn0),
                    phase: phase,
                    segments: fn0 > 0.60 ? 3 : 2
                )
                let style = StrokeStyle(
                    lineWidth: 0.34 + 0.92 * nearHorizon + 0.52 * fn1,
                    lineCap: .round,
                    lineJoin: .round
                )

                context.stroke(path, with: .color(color), style: style)
            }
        }
    }

    private static func glintFlicker(
        time: CGFloat,
        speed: CGFloat,
        phase: CGFloat,
        floor: CGFloat
    ) -> CGFloat {
        let wave = max(0, 0.5 + 0.5 * sin(time * speed + phase))
        let flare = pow(wave, 3.6)
        return floor + (1 - floor) * flare
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
            layer.addFilter(.blur(radius: 0.55))

            for index in 0..<124 {
                let seed = index * 29 + 5
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 11)
                let n2 = pseudoNoise(seed + 23)
                let n3 = pseudoNoise(seed + 37)
                let depth = (CGFloat(index) + 0.65 * n0) / 124
                let y = horizonY + 9 + depth * waterHeight * 0.96
                let drift = width * 0.026 * sin(t * (0.035 + 0.040 * n2) + CGFloat(index) * 0.91)
                let startX = width * (-0.14 + 1.28 * n1) + drift
                let length = width * (0.14 + 0.40 * n2) * (0.76 + 0.78 * depth)
                let amplitude = 0.8 + 5.4 * depth * (0.35 + n3)
                let phase = t * (0.055 + 0.080 * n0) + CGFloat(index) * 0.57
                let opacity = (0.030 + 0.062 * Double(1 - depth) + 0.030 * Double(breath)) * Double(0.46 + 0.60 * n2)
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
                    with: .color(Color(red: 0.56, green: 0.34 + 0.11 * Double(1 - depth), blue: 0.50 + 0.10 * Double(1 - depth)).opacity(opacity)),
                    style: StrokeStyle(lineWidth: 0.55 + 0.65 * depth + 0.45 * n0, lineCap: .round, lineJoin: .round)
                )
            }
        }

        for index in 0..<78 {
            let seed = index * 31 + 211
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 13)
            let n2 = pseudoNoise(seed + 29)
            let depth = (CGFloat(index) + 0.35 * n0) / 78
            let y = horizonY + waterHeight * (0.08 + 0.82 * depth)
            let sunPull = 1 - abs(depth - 0.36)
            let x = sunCenterX + (n1 - 0.5) * width * (0.22 + 0.70 * depth)
            let length = width * (0.040 + 0.140 * n2) * (0.92 + 0.52 * sunPull)
            let phase = t * (0.070 + 0.060 * n1) + CGFloat(index) * 1.13
            let path = wavePath(
                startX: x - length,
                endX: x + length,
                y: y,
                amplitude: 1.3 + 4.7 * depth,
                phase: phase,
                segments: 3
            )

            context.stroke(
                path,
                with: .color(Color(red: 1.0, green: 0.42 + 0.29 * Double(1 - depth), blue: 0.24).opacity((0.060 + 0.128 * Double(breath)) * Double(0.32 + 0.74 * n0))),
                style: StrokeStyle(lineWidth: 0.34 + 0.58 * n2, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private static func sunsetGlintPath(
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
        let current = CGPoint(x: startX, y: y + sin(phase) * amplitude * 0.30)

        path.move(to: current)

        for segment in 0..<segmentCount {
            let endProgress = CGFloat(segment + 1) / CGFloat(segmentCount)
            let midProgress = (CGFloat(segment) + 0.5) / CGFloat(segmentCount)
            let next = CGPoint(
                x: startX + width * endProgress,
                y: y + sin(phase + endProgress * .pi * 2.0) * amplitude * 0.36
            )
            let control = CGPoint(
                x: startX + width * midProgress,
                y: y + sin(phase + midProgress * .pi * 2.0) * amplitude
            )

            path.addQuadCurve(to: next, control: control)
        }

        return path
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
        case 4, 13:
            return Color(red: 0.45 + warmth * 0.20, green: 0.40 + warmth * 0.18 + jitter, blue: 1.0)
        case 5:
            return Color(red: 0.84 + warmth + jitter, green: 0.98 + warmth * 0.30, blue: 1.0)
        case 9:
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
