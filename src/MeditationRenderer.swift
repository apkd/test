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
        let continuousTime = CGFloat(time)
        let familyCount = 3
        let strandsPerFamily = reduceMotion ? 5 : 7
        let sampleCount = reduceMotion ? 44 : 54
        let minSide = min(width, height)
        let spread = (0.68 + 0.48 * breathEase) * motionScale
        let brightness = 0.90 + 0.42 * breathEase
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
            let center = CGPoint(x: 0.50, y: 0.535)
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
                (0.39, 0.82, 1.00),
                (0.54, 0.90, 1.00),
                (0.58, 0.56, 1.00),
            ]
            var base = palettes[family % palettes.count]
            let centerAccent = abs(lane) < 0.18
            let magenta = (strand + family) % 9 == 4
            let amber = (strand + family * 2) % 17 == 11
            let jitter = (seed - 0.5) * 0.024

            if magenta {
                base = (
                    mix(base.r, 0.82, amount: 0.22),
                    mix(base.g, 0.42, amount: 0.16),
                    mix(base.b, 0.92, amount: 0.12)
                )
            } else if amber && centerAccent {
                base = (
                    mix(base.r, 1.00, amount: 0.26),
                    mix(base.g, 0.74, amount: 0.18),
                    mix(base.b, 0.38, amount: 0.18)
                )
            }

            let warmMix = min(0.20, 0.035 + localBreath * 0.095 + (centerAccent ? 0.025 : 0))
            let warm = (r: CGFloat(1.00), g: CGFloat(0.46), b: CGFloat(0.76))
            return Color(
                red: Double(min(1, max(0, mix(base.r, warm.r, amount: warmMix) + jitter))),
                green: Double(min(1, max(0, mix(base.g, warm.g, amount: warmMix * 0.62) + jitter * 0.35))),
                blue: Double(min(1, max(0, mix(base.b, warm.b, amount: warmMix * 0.32))))
            )
        }

        for family in 0..<familyCount {
            let familySeed = family * 239 + 37
            let familyOffset = (CGFloat(family) - CGFloat(familyCount - 1) * 0.5) * 0.028
            let naturalOffset = familyOffset * (0.30 + 0.70 * breathEase)
            let familyNoise = pseudoNoise(familySeed)
            let depth = 0.58 + 0.42 * pseudoNoise(familySeed + 13)
            let amplitude = 0.060 + 0.026 * pseudoNoise(familySeed + 29) + 0.052 * breathEase
            let bandWidth = minSide * (0.028 + 0.010 * pseudoNoise(familySeed + 41)) * spread * (0.82 + 0.24 * depth)
            // Keep time independent from breath-dependent coefficients: `time * breathEase`
            // makes apparent speed grow with elapsed time. Cycle influence stays sinusoidal
            // so the ribbon field is continuous when the breathing cycle wraps.
            let familyPhase = continuousTime * 0.020 * (0.82 + 0.42 * familyNoise)
                + CGFloat(family) * 0.17
                + 0.24 * sin(cyclePhase + familyNoise * 2.7)
                + 0.10 * sin(2 * cyclePhase + CGFloat(family) * 0.9)
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
                let longArc = 0.028 * sin((progress - 0.08) * .pi * 2)
                let y = 0.636
                    - 0.218 * progress
                    + centerPull
                    + longArc * envelope
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
                let flow = progress * 2 * .pi
                let weaveNoise = signedNoise(progress * 3.55 + strandPhase * 0.42 + seed * 4.0, seed: familySeed + 173)
                let harmonicWeave = sin(flow * (1.48 + seed * 0.28) + strandPhase * 1.05 + seed * 5.4)
                    + 0.42 * sin(flow * (2.36 + seed * 0.22) - strandPhase * 0.72 + seed * 8.3)
                let localSpread = 0.88 + 0.28 * localBreath
                let waist = 0.34 + 0.66 * pow(abs(progress - 0.5) * 2, 0.72)
                let offset = lane * bandWidth * envelope * localSpread * waist
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
                let pulsePosition = CGFloat(wrappedUnit(
                    time * Double(0.020 + 0.006 * strandSeed)
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
                        auraWidth: (14.0 + 18.0 * centerWeight + 5.0 * strandSeed) * (0.88 + 0.24 * sustainedBreath),
                        bodyWidth: (3.2 + 4.1 * centerWeight + 0.9 * strandSeed) * (0.88 + 0.20 * sustainedBreath),
                        coreWidth: (0.42 + 0.92 * centerWeight + 0.14 * strandSeed) * (0.90 + 0.14 * sustainedBreath),
                        auraOpacity: Double(0.018 + 0.022 * centerWeight) * Double(brightness) * Double(frontWeight),
                        bodyOpacity: Double(0.092 + 0.082 * centerWeight) * Double(brightness) * Double(frontWeight),
                        coreOpacity: Double(0.092 + 0.245 * centerWeight) * Double(0.90 + 0.20 * sustainedBreath) * Double(frontWeight),
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

        drawSilkRibbonParticles(
            in: &context,
            size: size,
            breath: breathEase,
            time: time,
            reduceMotion: reduceMotion
        )

        let flareCenter = CGPoint(
            x: width * (0.51 + 0.012 * sin(cyclePhase)),
            y: height * (0.505 - 0.020 * breathEase)
        )

        context.drawLayer { layerContext in
            layerContext.addFilter(.blur(radius: 18))
            layerContext.fill(
                Path(ellipseIn: CGRect(
                    x: flareCenter.x - minSide * 0.28,
                    y: flareCenter.y - minSide * 0.17,
                    width: minSide * 0.56,
                    height: minSide * 0.34
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.18 + 0.12 * Double(breathEase)),
                        Color(red: 0.44, green: 0.86, blue: 1.0).opacity(0.17 + 0.08 * Double(breathEase)),
                        Color(red: 0.62, green: 0.34, blue: 1.0).opacity(0.12),
                        .clear,
                    ]),
                    center: flareCenter,
                    startRadius: 0,
                    endRadius: minSide * 0.28
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
            layerContext.addFilter(.blur(radius: 0.65))
            for string in strings {
                layerContext.stroke(
                    string.path.trimmedPath(from: 0.026, to: 0.974),
                    with: .color(string.color.opacity(string.bodyOpacity * 0.84)),
                    style: StrokeStyle(lineWidth: max(0.6, string.bodyWidth * 0.40), lineCap: .round, lineJoin: .round)
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
                    with: .color(Color.white.opacity(string.coreOpacity * 0.54)),
                    style: StrokeStyle(lineWidth: max(0.9, string.coreWidth * 0.82), lineCap: .round, lineJoin: .round)
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
    }

    private static func drawSilkRibbonParticles(
        in context: inout GraphicsContext,
        size: CGSize,
        breath: CGFloat,
        time: TimeInterval,
        reduceMotion: Bool
    ) {
        let width = size.width
        let height = size.height
        let count = reduceMotion ? 34 : 82
        let t = CGFloat(time)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.55))
            drawSilkRibbonParticleLayer(
                in: &layer,
                width: width,
                height: height,
                count: count,
                breath: breath,
                time: t
            )
        }
    }

    private static func drawSilkRibbonParticleLayer(
        in context: inout GraphicsContext,
        width: CGFloat,
        height: CGFloat,
        count: Int,
        breath: CGFloat,
        time: CGFloat
    ) {
        for index in 0..<count {
            let seed = index * 61 + 509
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 13)
            let n2 = pseudoNoise(seed + 29)
            let n3 = pseudoNoise(seed + 47)
            let progress = n0
            let envelope = pow(max(0, sin(progress * .pi)), 0.62)
            let baseX = width * (-0.04 + 1.08 * progress)
            let scatterX = width * (n1 - 0.5) * (0.05 + 0.16 * envelope)
            let driftPhaseX = time * (0.06 + 0.05 * n2) + n3 * .pi * 2
            let driftX = width * 0.012 * sin(driftPhaseX)
            let baseY = height * (0.64 - 0.22 * progress)
            let scatterY = height * (n2 - 0.5) * (0.05 + 0.15 * envelope)
            let driftPhaseY = time * (0.05 + 0.04 * n1) + n0 * .pi * 2
            let driftY = height * 0.010 * cos(driftPhaseY)
            let x = baseX + scatterX + driftX
            let y = baseY + scatterY + driftY
            let radius = 0.35 + 1.25 * n3
            let spark = n2 > 0.88
            let envelopeOpacity = 0.42 + 0.58 * envelope
            let breathOpacity = 0.78 + 0.36 * breath
            let baseOpacity = spark ? 0.20 : 0.055
            let opacity = Double(baseOpacity * envelopeOpacity * breathOpacity)
            let color: Color

            if spark {
                color = Color.white.opacity(opacity)
            } else {
                let red = 0.34 + 0.36 * Double(n1)
                let green = 0.62 + 0.30 * Double(n2)
                color = Color(red: red, green: green, blue: 1.0).opacity(opacity)
            }

            let diameter = radius * 2
            let rect = CGRect(x: x - radius, y: y - radius, width: diameter, height: diameter)
            context.fill(Path(ellipseIn: rect), with: .color(color))
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
        let skyBreath = CGFloat(BreathingTimeline.smoothstep(snapshot.breathAmount))
        let horizonY = height * 0.60
        let cameraWobble = CGFloat(sin(time * 0.17) * 1.4 + cos(time * 0.11) * 0.9) * motionScale
        let baseSunRadius = min(width, height) * 0.165
        let sunRadius = baseSunRadius * (0.975 + 0.05 * breath)
        let sunCenter = CGPoint(
            x: width * (0.5 + 0.012 * sin(CGFloat(time) * 0.08)),
            y: horizonY + cameraWobble + height * 0.065 - baseSunRadius * (0.52 + 0.64 * breath)
        )

        var sky = Path()
        sky.addRect(CGRect(x: 0, y: 0, width: width, height: horizonY))
        context.fill(
            sky,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.045 + 0.060 * Double(skyBreath), green: 0.055 + 0.045 * Double(skyBreath), blue: 0.165 + 0.105 * Double(skyBreath)),
                    Color(red: 0.110 + 0.125 * Double(skyBreath), green: 0.080 + 0.065 * Double(skyBreath), blue: 0.245 + 0.120 * Double(skyBreath)),
                    Color(red: 0.310 + 0.185 * Double(skyBreath), green: 0.150 + 0.080 * Double(skyBreath), blue: 0.350 + 0.080 * Double(skyBreath)),
                    Color(red: 0.650 + 0.265 * Double(skyBreath), green: 0.245 + 0.165 * Double(skyBreath), blue: 0.335 + 0.035 * Double(skyBreath)),
                    Color(red: 1.000, green: 0.390 + 0.200 * Double(skyBreath), blue: 0.255 + 0.050 * Double(skyBreath)),
                ]),
                startPoint: CGPoint(x: width * 0.2, y: 0),
                endPoint: CGPoint(x: width * 0.58, y: horizonY)
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
                        Color(red: 1.0, green: 0.72, blue: 0.42).opacity(0.30 + 0.12 * Double(breath)),
                        Color(red: 0.98, green: 0.36, blue: 0.29).opacity(0.14 + 0.08 * Double(breath)),
                        Color(red: 0.74, green: 0.18, blue: 0.34).opacity(0.045 + 0.04 * Double(breath)),
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
                        Color(red: 1.0, green: 0.80, blue: 0.48).opacity(0.62 + 0.16 * Double(breath)),
                        Color(red: 0.98, green: 0.42, blue: 0.30).opacity(0.20 + 0.10 * Double(breath)),
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
                    Color(red: 1.0, green: 0.93, blue: 0.60),
                    Color(red: 1.0, green: 0.66, blue: 0.38),
                    Color(red: 0.98, green: 0.48, blue: 0.34),
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
                    Color(red: 0.072 + 0.020 * Double(breath), green: 0.064 + 0.014 * Double(breath), blue: 0.145 + 0.028 * Double(breath)),
                    Color(red: 0.036, green: 0.034, blue: 0.092),
                    Color(red: 0.012, green: 0.018, blue: 0.052),
                ]),
                startPoint: CGPoint(x: width * 0.5, y: horizonY),
                endPoint: CGPoint(x: width * 0.5, y: height)
            )
        )

        context.fill(
            water,
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.95, green: 0.300, blue: 0.205).opacity(0.12 + 0.13 * Double(breath)),
                    Color(red: 0.55, green: 0.100, blue: 0.210).opacity(0.060 + 0.060 * Double(breath)),
                    .clear,
                ]),
                center: CGPoint(x: sunCenter.x, y: horizonY + (height - horizonY) * 0.10),
                startRadius: 0,
                endRadius: width * (0.22 + 0.10 * breath)
            )
        )

        drawOceanSurface(in: &context, size: size, horizonY: horizonY, breath: breath, time: time, sunCenterX: sunCenter.x)
        drawReflection(in: &context, size: size, horizonY: horizonY, breath: breath, time: time, sunCenterX: sunCenter.x)
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
                let opacity = (0.018 + 0.036 * Double(max(0, lowerGlow)) + 0.026 * Double(breath)) * Double(0.45 + n2)
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
                    with: .color(Color(red: 1.0, green: 0.42, blue: 0.24).opacity(0.030 + 0.035 * Double(breath))),
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
        let count = reduceMotion ? 70 : 170

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.25))

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
                let radius = 0.35 + 1.35 * n2
                let bright = n3 > 0.91
                let opacity = (bright ? 0.30 : 0.070)
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

            for index in 0..<(reduceMotion ? 4 : 9) {
                let seed = index * 97 + 1201
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 23)
                let n2 = pseudoNoise(seed + 41)
                let localCenter = CGPoint(
                    x: width * (0.12 + 0.76 * n0),
                    y: height * (0.18 + 0.68 * n1)
                )
                let radius = scale * (0.020 + 0.036 * n2)
                let alpha = 0.022 + 0.024 * Double(breath)

                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: localCenter.x - radius,
                        y: localCenter.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.88, green: 0.62, blue: 1.0).opacity(alpha),
                            Color(red: 0.35, green: 0.52, blue: 1.0).opacity(alpha * 0.50),
                            .clear,
                        ]),
                        center: localCenter,
                        startRadius: 0,
                        endRadius: radius
                    )
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
        let glowLevel = 0.56 + 0.44 * breathEase
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
                    Color(red: 0.42, green: 0.51, blue: 0.92).opacity((0.11 + 0.055 * Double(breath)) * Double(glowLevel)),
                    Color(red: 0.34, green: 0.43, blue: 0.82).opacity((0.094 + 0.044 * Double(breath)) * Double(glowLevel)),
                    Color(red: 0.26, green: 0.34, blue: 0.68).opacity((0.074 + 0.036 * Double(breath)) * Double(glowLevel)),
                    Color(red: 0.19, green: 0.25, blue: 0.54).opacity((0.052 + 0.028 * Double(breath)) * Double(glowLevel)),
                    Color(red: 0.12, green: 0.17, blue: 0.38).opacity((0.030 + 0.018 * Double(breath)) * Double(glowLevel)),
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
                let opacity = (0.030 + 0.030 * Double(localPulse) + 0.036 * Double(breath)) * Double(glowLevel)

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

        context.fill(
            Path(CGRect(x: 0, y: 0, width: width, height: height)),
            with: .color(.black.opacity(0.20 * Double(exhaleDepth)))
        )

        drawSoftGlowGrain(
            in: &context,
            size: size,
            count: reduceMotion ? 700 : 2_400,
            alphaScale: (reduceMotion ? 1.05 : 1.55) * (1.0 + 0.28 * Double(exhaleDepth))
        )
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

    private static func drawBlurredSunsetReflection(
        in context: inout GraphicsContext,
        width: CGFloat,
        waterHeight: CGFloat,
        horizonY: CGFloat,
        breath: CGFloat,
        time: CGFloat,
        sunCenterX: CGFloat
    ) {
        let total = CGFloat(128)
        let pi2 = CGFloat.pi * 2

        for index in 0..<128 {
            let seed = index * 41 + 113
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 7)
            let n2 = pseudoNoise(seed + 17)
            let n3 = pseudoNoise(seed + 31)
            let depth = (CGFloat(index) + n0 * 0.45) / total
            let nearHorizon = max(0, 1 - depth)
            let midColumn = max(0, 1 - abs(depth - 0.22) / 0.42)
            let y = horizonY + 4 + depth * waterHeight * 0.84

            let columnBase = 0.020 + 0.155 * nearHorizon + 0.090 * midColumn
            let columnHalf = width * columnBase
            let driftPhase = time * (0.36 + 0.34 * n2) + n3 * pi2
            let drift = width * (0.004 + 0.010 * depth) * sin(driftPhase)
            let centerX = sunCenterX + (n1 - 0.5) * columnHalf * 1.55 + drift

            let glintBase = 0.012 + 0.060 * nearHorizon + 0.038 * midColumn
            let scalePhase = time * (0.52 + 0.58 * n1) + n2 * pi2
            let widthScale = 0.45 + 0.75 * (0.5 + 0.5 * sin(scalePhase))
            let halfWidth = width * glintBase * (0.32 + 0.88 * n2) * widthScale
            let shimmer = glintFlicker(time: time, speed: 1.10 + 1.95 * n0, phase: n3 * pi2, floor: 0.10)
            let opacityBase = 0.045 + 0.100 * Double(breath)
            let depthGain = 0.34 + 0.86 * nearHorizon + 0.62 * midColumn
            let noiseGain = 0.48 + 0.90 * n2
            let opacity = opacityBase * Double(depthGain) * Double(noiseGain) * Double(shimmer)

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
                lineWidth: 1.2 + 2.2 * nearHorizon + 0.7 * n0,
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
        let total = CGFloat(220)
        let pi2 = CGFloat.pi * 2

        for index in 0..<220 {
            let seed = index * 43 + 227
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 13)
            let n2 = pseudoNoise(seed + 29)
            let n3 = pseudoNoise(seed + 41)
            let depth = (CGFloat(index) + 0.5 * n0) / total
            let nearHorizon = max(0, 1 - depth)
            let midColumn = max(0, 1 - abs(depth - 0.25) / 0.48)
            let y = horizonY + 5 + depth * waterHeight * 0.90
            let columnBase = 0.026 + 0.165 * nearHorizon + 0.105 * midColumn
            let columnHalf = width * columnBase
            let rowPhase = time * (0.42 + 0.44 * n3) + n2 * pi2
            let rowDrift = width * (0.004 + 0.010 * depth) * sin(rowPhase)
            let centerX = sunCenterX + rowDrift + (n1 - 0.5) * columnHalf * 1.85
            let fragmentCount = n2 > 0.72 ? 3 : (n2 > 0.30 ? 2 : 1)

            for fragment in 0..<fragmentCount {
                let f = CGFloat(fragment)
                let fn0 = pseudoNoise(seed + fragment * 67 + 101)
                let fn1 = pseudoNoise(seed + fragment * 67 + 119)
                let offsetX = (fn0 - 0.5) * columnHalf * (0.35 + 0.42 * depth)
                let widthBase = 0.005 + 0.043 * nearHorizon + 0.026 * midColumn
                let scalePhase = time * (0.70 + 0.72 * fn0) + fn1 * pi2 + f
                let widthScale = 0.36 + 0.88 * (0.5 + 0.5 * sin(scalePhase))
                let halfWidth = width * widthBase * (0.30 + 1.10 * fn1) * widthScale / CGFloat(fragmentCount)
                let phase = n3 * pi2 + f * 0.63
                let flicker = glintFlicker(time: time, speed: 1.25 + 2.40 * fn1, phase: fn0 * pi2 + f, floor: 0.045)
                let depthBrightness = 0.022 + 0.142 * Double(nearHorizon) + 0.086 * Double(midColumn)
                let breathBrightness = 0.70 + 0.82 * Double(breath)
                let noiseBrightness = 0.58 + 0.84 * Double(fn1)
                let brightness = depthBrightness * breathBrightness * noiseBrightness * Double(flicker)
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
                    lineWidth: 0.55 + 1.65 * nearHorizon + 0.85 * fn1,
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

            for index in 0..<54 {
                let seed = index * 29 + 5
                let n0 = pseudoNoise(seed)
                let n1 = pseudoNoise(seed + 11)
                let n2 = pseudoNoise(seed + 23)
                let n3 = pseudoNoise(seed + 37)
                let depth = (CGFloat(index) + 0.65 * n0) / 54
                let y = horizonY + 9 + depth * waterHeight * 0.96
                let drift = width * 0.026 * sin(t * (0.035 + 0.040 * n2) + CGFloat(index) * 0.91)
                let startX = width * (-0.14 + 1.28 * n1) + drift
                let length = width * (0.12 + 0.34 * n2) * (0.70 + 0.72 * depth)
                let amplitude = 0.8 + 5.4 * depth * (0.35 + n3)
                let phase = t * (0.055 + 0.080 * n0) + CGFloat(index) * 0.57
                let opacity = (0.012 + 0.026 * Double(1 - depth) + 0.012 * Double(breath)) * Double(0.45 + 0.55 * n2)
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
                    with: .color(Color(red: 0.42, green: 0.28 + 0.08 * Double(1 - depth), blue: 0.48 + 0.10 * Double(1 - depth)).opacity(opacity)),
                    style: StrokeStyle(lineWidth: 0.55 + 0.65 * depth + 0.45 * n0, lineCap: .round, lineJoin: .round)
                )
            }
        }

        for index in 0..<26 {
            let seed = index * 31 + 211
            let n0 = pseudoNoise(seed)
            let n1 = pseudoNoise(seed + 13)
            let n2 = pseudoNoise(seed + 29)
            let depth = (CGFloat(index) + 0.35 * n0) / 26
            let y = horizonY + waterHeight * (0.08 + 0.82 * depth)
            let sunPull = 1 - abs(depth - 0.36)
            let x = sunCenterX + (n1 - 0.5) * width * (0.22 + 0.70 * depth)
            let length = width * (0.040 + 0.145 * n2) * (0.8 + 0.42 * sunPull)
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
                with: .color(Color(red: 1.0, green: 0.30 + 0.24 * Double(1 - depth), blue: 0.24).opacity((0.014 + 0.050 * Double(breath)) * Double(0.28 + 0.72 * n0))),
                style: StrokeStyle(lineWidth: 0.45 + 0.75 * n2, lineCap: .round, lineJoin: .round)
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
