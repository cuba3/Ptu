// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

enum CameraRawPixels {
    static func apply(_ settings: CameraRawSettings, to buffer: PixelBuffer) -> PixelBuffer {
        var image = buffer
        if settings.geometry.adjusts {
            image = settings.geometry.apply(image)
        }
        if settings.calibration.adjusts {
            image = calibration(settings.calibration, image)
        }
        image = basicGrade(settings, image)
        if settings.curve.adjusts || settings.mixer.adjusts || settings.grading.adjusts {
            image = curveColor(settings, image)
        }
        if settings.texture != 0 || settings.clarity != 0 || settings.dehaze != 0 || settings.glow > 0 || settings.vignetteAmount != 0 {
            image = effects(settings, image)
        }
        if settings.grainAmount > 0 {
            var grain = GrainSettings()
            grain.amount = settings.grainAmount
            grain.size = settings.grainKernelSize
            grain.roughness = settings.grainRoughness
            grain.seed = settings.grainSeed
            image = grain.apply(image)
        }
        if settings.optics.adjusts {
            image = optics(settings.optics, image)
        }
        if settings.detail.adjusts {
            image = detail(settings.detail, image)
        }
        return image
    }

    static func vignetteMask(x: Int, y: Int, width: Int, height: Int, midpoint: Double, roundness: Double, feather: Double) -> Double {
        guard width > 0, height > 0 else { return 0 }
        let nx = (Double(x) + 0.5) / Double(width) * 2 - 1
        let ny = (Double(y) + 0.5) / Double(height) * 2 - 1
        let square = max(abs(nx), abs(ny))
        let circle = hypot(nx, ny) / 2.squareRoot()
        let shape = (1 - roundness / 100) * 0.5
        let dist = circle + (square - circle) * shape
        let start = (midpoint / 100) * 0.85
        let soft = max(0.05, feather / 100)
        let t = PixelMath.clampUnit((dist - start) / soft)
        return t * t * (3 - 2 * t)
    }

    private static func basicGrade(_ settings: CameraRawSettings, _ buffer: PixelBuffer) -> PixelBuffer {
        let gains = settings.gains
        let light = pow(2, settings.exposure)
        let contrastScale = 1 + settings.contrast / 100
        let highlightAmount = settings.highlights / 100
        let shadowAmount = settings.shadows / 100
        let whiteAmount = settings.whites / 100
        let blackAmount = settings.blacks / 100
        let vibranceAmount = settings.vibrance / 100
        let saturationAmount = settings.saturation / 100
        let unchanged = settings.exposure == 0 && settings.contrast == 0 && settings.highlights == 0 && settings.shadows == 0
            && settings.whites == 0 && settings.blacks == 0 && settings.temperature == 0 && settings.tint == 0
            && settings.vibrance == 0 && settings.saturation == 0
        guard !unchanged else { return buffer }
        return PixelMath.mapColors(buffer) { r, g, b, _, _ in
            r = PixelMath.clampUnit(PixelMath.srgbToLinear(r) * gains.red * light)
            g = PixelMath.clampUnit(PixelMath.srgbToLinear(g) * gains.green * light)
            b = PixelMath.clampUnit(PixelMath.srgbToLinear(b) * gains.blue * light)
            r = PixelMath.clampUnit(0.5 + (PixelMath.linearToSRGB(r) - 0.5) * contrastScale)
            g = PixelMath.clampUnit(0.5 + (PixelMath.linearToSRGB(g) - 0.5) * contrastScale)
            b = PixelMath.clampUnit(0.5 + (PixelMath.linearToSRGB(b) - 0.5) * contrastScale)
            PixelMath.scaleLuminance(&r, &g, &b, target: toneHighlights(PixelMath.rec709(r, g, b), highlightAmount))
            PixelMath.scaleLuminance(&r, &g, &b, target: toneShadows(PixelMath.rec709(r, g, b), shadowAmount))
            PixelMath.scaleLuminance(&r, &g, &b, target: toneWhites(PixelMath.rec709(r, g, b), whiteAmount))
            PixelMath.scaleLuminance(&r, &g, &b, target: toneBlacks(PixelMath.rec709(r, g, b), blackAmount))
            vibrance(&r, &g, &b, vibrance: vibranceAmount, saturation: saturationAmount)
        }
    }

    private static func toneHighlights(_ y: Double, _ amount: Double) -> Double {
        let t = PixelMath.clampUnit((y - 0.5) / 0.5)
        let weight = t * t
        if amount >= 0 { return PixelMath.clampUnit(y + amount * weight * (1 - y)) }
        return PixelMath.clampUnit(y + amount * weight * (y - 0.5))
    }

    private static func toneShadows(_ y: Double, _ amount: Double) -> Double {
        let t = PixelMath.clampUnit((0.5 - y) / 0.5)
        let weight = t * t
        if amount >= 0 { return PixelMath.clampUnit(y + amount * weight * (0.5 - y)) }
        return PixelMath.clampUnit(y + amount * weight * y)
    }

    private static func toneWhites(_ y: Double, _ amount: Double) -> Double {
        guard y > 0.75 else { return y }
        return PixelMath.clampUnit(0.75 + (y - 0.75) * (1 + amount))
    }

    private static func toneBlacks(_ y: Double, _ amount: Double) -> Double {
        guard y < 0.25 else { return y }
        return PixelMath.clampUnit(0.25 + (y - 0.25) * (1 - amount))
    }

    private static func vibrance(_ r: inout Double, _ g: inout Double, _ b: inout Double, vibrance: Double, saturation: Double) {
        var lum = PixelMath.rec709(r, g, b)
        let maxChannel = max(r, g, b)
        let minChannel = min(r, g, b)
        let chroma = maxChannel - minChannel
        let sat = maxChannel <= 1e-8 ? 0 : chroma / maxChannel
        var hue = 0.0
        if chroma > 1e-8 {
            if r >= g && r >= b { hue = 60 * ((g - b) / chroma).truncatingRemainder(dividingBy: 6) }
            else if g >= r && g >= b { hue = 60 * ((b - r) / chroma + 2) }
            else { hue = 60 * ((r - g) / chroma + 4) }
            if hue < 0 { hue += 360 }
        }
        var skin = 0.0
        if hue >= 10 && hue <= 50 {
            skin = hue <= 30 ? (hue - 10) / 20 : (50 - hue) / 20
            skin *= PixelMath.clampUnit((sat - 0.15) / 0.35)
        }
        var amount = vibrance * (1 - sat)
        if vibrance > 0 { amount *= 1 - 0.7 * skin }
        var factor = 1 + amount
        r = PixelMath.clampUnit(lum + (r - lum) * factor)
        g = PixelMath.clampUnit(lum + (g - lum) * factor)
        b = PixelMath.clampUnit(lum + (b - lum) * factor)
        lum = PixelMath.rec709(r, g, b)
        factor = 1 + saturation
        r = PixelMath.clampUnit(lum + (r - lum) * factor)
        g = PixelMath.clampUnit(lum + (g - lum) * factor)
        b = PixelMath.clampUnit(lum + (b - lum) * factor)
    }

    private static func curveColor(_ settings: CameraRawSettings, _ buffer: PixelBuffer) -> PixelBuffer {
        let curve = settings.curve.normalized
        let tone = curve.toneTable()
        let red = curve.channelTable(curve.red)
        let green = curve.channelTable(curve.green)
        let blue = curve.channelTable(curve.blue)
        let mixer = settings.mixer
        let grading = settings.grading
        let c30 = 30.0 / 360.0
        let c60 = 60.0 / 360.0
        let c120 = 120.0 / 360.0
        let c180 = 180.0 / 360.0
        let c240 = 240.0 / 360.0
        let c270 = 270.0 / 360.0
        let c300 = 300.0 / 360.0
        let centers = [0.0, c30, c60, c120, c180, c240, c270, c300]
        let refine = curve.refineSaturation / 100
        return PixelMath.mapColors(buffer) { r, g, b, _, _ in
            gradePixel(&r, &g, &b, tone: tone, redLUT: red, greenLUT: green, blueLUT: blue, refine: refine, mixer: mixer, grading: grading, centers: centers)
        }
    }

    private static func gradePixel(
        _ r: inout Double,
        _ g: inout Double,
        _ b: inout Double,
        tone: [Double],
        redLUT: [Double],
        greenLUT: [Double],
        blueLUT: [Double],
        refine: Double,
        mixer: CameraRawMixerSettings,
        grading: CameraRawGradingSettings,
        centers: [Double]
    ) {
            applyToneCurve(&r, &g, &b, tone: tone, redLUT: redLUT, greenLUT: greenLUT, blueLUT: blueLUT, refine: refine)
            applyMixer(&r, &g, &b, mixer: mixer, centers: centers)
            applyGrading(&r, &g, &b, grading: grading)
    }

    private static func applyToneCurve(
        _ r: inout Double,
        _ g: inout Double,
        _ b: inout Double,
        tone: [Double],
        redLUT: [Double],
        greenLUT: [Double],
        blueLUT: [Double],
        refine: Double
    ) {
            var curvedR = lut(tone, r)
            var curvedG = lut(tone, g)
            var curvedB = lut(tone, b)
            if refine < 0 {
                var br = r
                var bg = g
                var bb = b
                let target = lut(tone, PixelMath.rec709(r, g, b))
                PixelMath.scaleLuminance(&br, &bg, &bb, target: target)
                curvedR += (br - curvedR) * -refine
                curvedG += (bg - curvedG) * -refine
                curvedB += (bb - curvedB) * -refine
            } else if refine > 0 {
                let lum = PixelMath.rec709(curvedR, curvedG, curvedB)
                let factor = 1 + refine
                curvedR = PixelMath.clampUnit(lum + (curvedR - lum) * factor)
                curvedG = PixelMath.clampUnit(lum + (curvedG - lum) * factor)
                curvedB = PixelMath.clampUnit(lum + (curvedB - lum) * factor)
            }
            r = lut(redLUT, curvedR)
            g = lut(greenLUT, curvedG)
            b = lut(blueLUT, curvedB)
    }

    private static func applyMixer(
        _ r: inout Double,
        _ g: inout Double,
        _ b: inout Double,
        mixer: CameraRawMixerSettings,
        centers: [Double]
    ) {
            var hsl = PixelMath.rgbToHSLUnit(r, g, b)
            var hueDelta = 0.0
            var satDelta = 0.0
            var lumDelta = 0.0
            var weightSum = 0.0
            if mixer.hue.count == 8 {
                for index in 0..<8 {
                    let distance = circular(hsl.h, centers[index])
                    let weight = 1 - distance / (40.0 / 360)
                    guard weight > 0 else { continue }
                    hueDelta += mixer.hue[index] / 100 * weight * (30.0 / 360)
                    satDelta += mixer.saturation[index] / 100 * weight
                    lumDelta += mixer.luminance[index] / 100 * weight * 0.25
                    weightSum += weight
                }
            }
            if weightSum > 1 {
                hueDelta /= weightSum
                satDelta /= weightSum
                lumDelta /= weightSum
            }
            hsl.h = wrapUnit(hsl.h + hueDelta)
            hsl.s = PixelMath.clampUnit(hsl.s * (1 + satDelta))
            hsl.l = PixelMath.clampUnit(hsl.l + lumDelta)
            let rgb = PixelMath.hslUnitToRGB(hsl.h, hsl.s, hsl.l)
            r = rgb.r
            g = rgb.g
            b = rgb.b
    }

    private static func applyGrading(
        _ r: inout Double,
        _ g: inout Double,
        _ b: inout Double,
        grading: CameraRawGradingSettings
    ) {
            let split = 0.5 - grading.balance / 100 * 0.2
            let reach = 0.12 + grading.blending / 100 * 0.38
            let luma = PixelMath.rec709(r, g, b)
            var shadowW = PixelMath.clampUnit((split + reach - luma) / max(0.05, reach * 2))
            var highlightW = PixelMath.clampUnit((luma - (split - reach)) / max(0.05, reach * 2))
            var midW = PixelMath.clampUnit(1 - abs(luma - split) / (0.35 + reach))
            let sum = shadowW + midW + highlightW
            if sum > 1e-4 {
                shadowW /= sum
                midW /= sum
                highlightW /= sum
            }
            let weights = [shadowW, midW, highlightW, 1.0]
            for (index, wheel) in grading.wheels.enumerated() {
                let weight = weights[index]
                guard weight > 0, wheel.saturation > 0 || wheel.luminance != 0 else { continue }
                let tint = PixelMath.hslUnitToRGB(wheel.hue / 360, 1, 0.5)
                let sat = wheel.saturation / 100
                r = PixelMath.clampUnit(r + (tint.r - 0.5) * sat * weight * 0.85)
                g = PixelMath.clampUnit(g + (tint.g - 0.5) * sat * weight * 0.85)
                b = PixelMath.clampUnit(b + (tint.b - 0.5) * sat * weight * 0.85)
                if wheel.luminance != 0 {
                    PixelMath.scaleLuminance(&r, &g, &b, target: PixelMath.clampUnit(PixelMath.rec709(r, g, b) + wheel.luminance / 100 * 0.25 * weight))
                }
            }
    }

    private static func lut(_ table: [Double], _ value: Double) -> Double {
        let scaled = PixelMath.clampUnit(value) * 255
        let lo = Int(scaled)
        let hi = min(255, lo + 1)
        let t = scaled - Double(lo)
        return table[lo] + (table[hi] - table[lo]) * t
    }

    private static func circular(_ a: Double, _ b: Double) -> Double {
        let distance = abs(a - b)
        return distance > 0.5 ? 1 - distance : distance
    }

    private static func wrapUnit(_ value: Double) -> Double {
        var value = value
        if value < 0 { value += 1 }
        if value >= 1 { value -= 1 }
        return value
    }

    private static func effects(_ settings: CameraRawSettings, _ buffer: PixelBuffer) -> PixelBuffer {
        let width = buffer.width
        let height = buffer.height
        let luma = PixelMath.lumaPlane(buffer)
        let fine = settings.texture != 0 ? PixelMath.boxBlur(luma, width: width, height: height, radius: 1) : nil
        let coarse = settings.clarity != 0 ? PixelMath.boxBlur(luma, width: width, height: height, radius: 4) : nil
        var glowPlane: [Float]?
        if settings.glow > 0 {
            let spread = settings.glowSpread / 100
            let base = settings.glowStyle == .bloom ? 2.0 : 5.0
            let radius = max(1, Int((base * (1 + spread)).rounded()))
            let threshold = Float(0.55 + 0.4 * (settings.glowRange / 100))
            let denom = max(0.05, 1 - threshold)
            let source = luma.map { sample -> Float in
                let t = (sample - threshold) / denom
                return min(1, max(0, t))
            }
            glowPlane = PixelMath.boxBlur(source, width: width, height: height, radius: min(64, radius))
        }
        let warmth = settings.glowWarmth / 100
        let glowTint: (r: Double, g: Double, b: Double, gain: Double)
        if settings.glowStyle == .halation {
            glowTint = (1, 0.35 - 0.3 * warmth, 0.2 - 0.2 * warmth, 1)
        } else {
            glowTint = (0.75 + 0.25 * warmth, 0.6 + 0.2 * warmth, 0.75 - 0.6 * warmth, settings.glowStyle == .bloom ? 1.4 : 1)
        }
        return PixelMath.mapColors(buffer) { r, g, b, x, y in
            let index = y * width + x
            if fine != nil || coarse != nil {
                let tone = PixelMath.rec709(r, g, b)
                var detail = 0.0
                if let fine { detail += (settings.texture / 100) * Double(tone - Double(fine[index])) }
                if let coarse { detail += (settings.clarity / 100) * Double(tone - Double(coarse[index])) }
                if detail != 0 {
                    PixelMath.scaleLuminance(&r, &g, &b, target: PixelMath.clampUnit(tone + detail))
                }
            }
            if settings.dehaze != 0 { dehaze(&r, &g, &b, settings.dehaze) }
            if let glowPlane, settings.glow > 0 {
                let add = Double(glowPlane[index]) * (settings.glow / 100) * glowTint.gain
                r = PixelMath.clampUnit(r + add * glowTint.r)
                g = PixelMath.clampUnit(g + add * glowTint.g)
                b = PixelMath.clampUnit(b + add * glowTint.b)
            }
            let mask = vignetteMask(
                x: x, y: y, width: width, height: height,
                midpoint: settings.vignetteMidpoint, roundness: settings.vignetteRoundness, feather: settings.vignetteFeather
            )
            var effect = (settings.vignetteAmount / 100) * mask
            if effect < 0 && settings.vignetteStyle == .highlightPriority {
                let bright = PixelMath.clampUnit((PixelMath.rec709(r, g, b) - 0.45) / 0.55)
                effect *= 1 - (settings.vignetteHighlights / 100) * bright
            }
            if effect < 0 {
                let factor = 1 + effect
                r *= factor
                g *= factor
                b *= factor
            } else if effect > 0 {
                r += (1 - r) * effect
                g += (1 - g) * effect
                b += (1 - b) * effect
            }
            if settings.vignetteStyle == .colorPriority && mask > 0 {
                let lum = PixelMath.rec709(r, g, b)
                let sat = 1 - 0.75 * mask * abs(settings.vignetteAmount / 100)
                r = PixelMath.clampUnit(lum + (r - lum) * sat)
                g = PixelMath.clampUnit(lum + (g - lum) * sat)
                b = PixelMath.clampUnit(lum + (b - lum) * sat)
            }
        }
    }

    private static func dehaze(_ r: inout Double, _ g: inout Double, _ b: inout Double, _ amount: Double) {
        let d = amount / 100
        let y = PixelMath.rec709(r, g, b)
        let contrast = 1 + 0.8 * d
        let pivot = 0.45 - 0.1 * (d > 0 ? d : 0)
        var y2 = PixelMath.clampUnit(pivot + (y - 0.45) * contrast)
        if d < 0 { y2 = PixelMath.clampUnit(y2 + (-d) * (1 - y2) * 0.45) }
        else { y2 = PixelMath.clampUnit(y2 - d * max(0, 0.4 - y2)) }
        PixelMath.scaleLuminance(&r, &g, &b, target: y2)
        y2 = PixelMath.rec709(r, g, b)
        let sat = 1 + 0.7 * d
        r = PixelMath.clampUnit(y2 + (r - y2) * sat)
        g = PixelMath.clampUnit(y2 + (g - y2) * sat)
        b = PixelMath.clampUnit(y2 + (b - y2) * sat)
    }

    private static func calibration(_ settings: CameraRawCalibrationSettings, _ buffer: PixelBuffer) -> PixelBuffer {
        let version = settings.process.kernelValue
        let versionScale = version <= 1 ? 0.55 : version == 2 ? 0.65 : version == 3 ? 0.75 : version == 4 ? 0.85 : version == 5 ? 0.92 : 1
        let tint = settings.shadowTint / 100 * versionScale
        let shifts = (
            redHue: settings.redHue / 100 * (15.0 / 360) * versionScale,
            redSat: settings.redSaturation / 100 * 0.45 * versionScale,
            greenHue: settings.greenHue / 100 * (15.0 / 360) * versionScale,
            greenSat: settings.greenSaturation / 100 * 0.45 * versionScale,
            blueHue: settings.blueHue / 100 * (15.0 / 360) * versionScale,
            blueSat: settings.blueSaturation / 100 * 0.45 * versionScale
        )
        return PixelMath.mapColors(buffer) { r, g, b, _, _ in
            var hsl = PixelMath.rgbToHSLUnit(r, g, b)
            if hsl.l < 0.35 && tint != 0 { hsl.h = wrapUnit(hsl.h + tint * 0.06) }
            if max(r, g, b) - min(r, g, b) > 1e-5 {
                if r >= g && r >= b {
                    hsl.h = wrapUnit(hsl.h + shifts.redHue)
                    hsl.s = PixelMath.clampUnit(hsl.s * (1 + shifts.redSat))
                } else if g >= r && g >= b {
                    hsl.h = wrapUnit(hsl.h + shifts.greenHue)
                    hsl.s = PixelMath.clampUnit(hsl.s * (1 + shifts.greenSat))
                } else {
                    hsl.h = wrapUnit(hsl.h + shifts.blueHue)
                    hsl.s = PixelMath.clampUnit(hsl.s * (1 + shifts.blueSat))
                }
            }
            let rgb = PixelMath.hslUnitToRGB(hsl.h, hsl.s, hsl.l)
            r = rgb.r
            g = rgb.g
            b = rgb.b
        }
    }

    private static func optics(_ settings: CameraRawOpticsSettings, _ buffer: PixelBuffer) -> PixelBuffer {
        let settings = settings.normalized
        var image = buffer
        let k = settings.distortionK(profileStrength: PixelFilter.lensStrength)
        if k != 0 { image = PixelFilter.lensDistort(image, k: k) }
        if settings.removeChromaticAberration { image = chromatic(image, strength: 0.45) }
        let vignette = settings.vignetteAmount + (settings.enableLensProfile ? settings.profileVignetting / 100 * 35 : 0)
        guard settings.purpleAmount != 0 || settings.greenAmount != 0 || vignette != 0 else { return image }
        return PixelMath.mapColors(image) { r, g, b, x, y in
            defringe(&r, &g, &b, settings: settings)
            guard vignette != 0 else { return }
            let nx = (Double(x) + 0.5) / Double(image.width) * 2 - 1
            let ny = (Double(y) + 0.5) / Double(image.height) * 2 - 1
            let dist = hypot(nx, ny) / 2.squareRoot()
            let start = (settings.vignetteMidpoint / 100) * 0.85
            let t = PixelMath.clampUnit((dist - start) / 0.35)
            let mask = t * t * (3 - 2 * t)
            let lift = (vignette / 100) * mask
            if lift > 0 {
                r = PixelMath.clampUnit(r + (1 - r) * lift)
                g = PixelMath.clampUnit(g + (1 - g) * lift)
                b = PixelMath.clampUnit(b + (1 - b) * lift)
            } else {
                r *= 1 + lift
                g *= 1 + lift
                b *= 1 + lift
            }
        }
    }

    private static func defringe(_ r: inout Double, _ g: inout Double, _ b: inout Double, settings: CameraRawOpticsSettings) {
        let hsl = PixelMath.rgbToHSL(r, g, b)
        let chroma = max(r, g, b) - min(r, g, b)
        guard chroma > 1e-6 else { return }
        let sat = chroma / max(r, g, b)
        var reduce = 0.0
        if settings.purpleAmount > 0 && hue(hsl.h, in: settings.purpleHueLow...settings.purpleHueHigh) {
            reduce = max(reduce, settings.purpleAmount / 100)
        }
        if settings.greenAmount > 0 && hue(hsl.h, in: settings.greenHueLow...settings.greenHueHigh) {
            reduce = max(reduce, settings.greenAmount / 100)
        }
        guard reduce > 0 else { return }
        let lum = PixelMath.rec709(r, g, b)
        let factor = 1 - reduce * sat
        r = PixelMath.clampUnit(lum + (r - lum) * factor)
        g = PixelMath.clampUnit(lum + (g - lum) * factor)
        b = PixelMath.clampUnit(lum + (b - lum) * factor)
    }

    private static func hue(_ value: Double, in range: ClosedRange<Double>) -> Bool {
        if range.lowerBound <= range.upperBound { return range.contains(value) }
        return value >= range.lowerBound || value <= range.upperBound
    }

    private static func chromatic(_ buffer: PixelBuffer, strength: Double) -> PixelBuffer {
        let width = buffer.width
        let height = buffer.height
        let cx = Double(width) * 0.5
        let cy = Double(height) * 0.5
        let maxR = hypot(cx, cy)
        var result = buffer
        let source = buffer
        result.updateEach { x, y, pixel in
            guard pixel.a > 0 else { return }
            let dx = Double(x) + 0.5 - cx
            let dy = Double(y) + 0.5 - cy
            let radial = hypot(dx, dy) / maxR
            let shift = strength * radial * radial * 2.5
            let rx = min(width - 1, max(0, Int((Double(x) - shift).rounded())))
            let bx = min(width - 1, max(0, Int((Double(x) + shift).rounded())))
            pixel.r = source.pixel(x: rx, y: y).r
            pixel.b = source.pixel(x: bx, y: y).b
        }
        return result
    }

    private static func detail(_ settings: CameraRawDetailSettings, _ buffer: PixelBuffer) -> PixelBuffer {
        let settings = settings.normalized
        var image = buffer
        let width = image.width
        let height = image.height
        if settings.noiseLuminance > 0 {
            let luma = PixelMath.lumaPlane(image)
            let radius = max(1, min(64, Int((1 + settings.noiseLuminance / 50).rounded())))
            let blurred = PixelMath.boxBlur(luma, width: width, height: height, radius: radius)
            let strength = settings.noiseLuminance / 100
            let preserve = settings.noiseLuminanceDetail / 100
            let contrast = settings.noiseLuminanceContrast / 100
            image = PixelMath.mapColors(image) { r, g, b, x, y in
                let index = y * width + x
                let edge = edgeAt(luma, width: width, height: height, x: x, y: y, radius: 1)
                let local = strength * (1 - preserve * min(1, Double(edge) * 6))
                var target = Double(luma[index]) * (1 - local) + Double(blurred[index]) * local
                if contrast != 0 { target += contrast * 0.25 * Double(luma[index] - blurred[index]) }
                PixelMath.scaleLuminance(&r, &g, &b, target: PixelMath.clampUnit(target))
            }
        }
        if settings.sharpenAmount > 0 {
            let luma = PixelMath.lumaPlane(image)
            let radius = max(1, min(64, Int((0.5 + (settings.sharpenRadius / 100) * 2.5).rounded())))
            let blurred = PixelMath.boxBlur(luma, width: width, height: height, radius: radius)
            let amount = settings.sharpenAmount / 100
            let detailMix = settings.sharpenDetail / 100
            let threshold = (settings.sharpenMasking / 100) * 0.35
            image = PixelMath.mapColors(image) { r, g, b, x, y in
                let index = y * width + x
                let edge = edgeAt(luma, width: width, height: height, x: x, y: y, radius: radius)
                let mask = PixelMath.clampUnit((Double(edge) * (0.5 + detailMix) - threshold) / max(0.04, 0.35 - threshold * 0.5))
                let high = Double(luma[index] - blurred[index])
                let sharpened = PixelMath.clampUnit(Double(luma[index]) + high * amount * mask * (0.5 + detailMix))
                PixelMath.scaleLuminance(&r, &g, &b, target: sharpened)
            }
        }
        return image
    }

    private static func edgeAt(_ luma: [Float], width: Int, height: Int, x: Int, y: Int, radius: Int) -> Float {
        let radius = max(1, radius)
        let center = luma[y * width + x]
        var sum: Float = 0
        var count = 0
        var dy = -radius
        while dy <= radius {
            var dx = -radius
            while dx <= radius {
                if dx != 0 || dy != 0 {
                    let sx = x + dx
                    let sy = y + dy
                    if sx >= 0, sy >= 0, sx < width, sy < height {
                        sum += abs(luma[sy * width + sx] - center)
                        count += 1
                    }
                }
                dx += radius
            }
            dy += radius
        }
        return count > 0 ? sum / Float(count) : 0
    }
}
