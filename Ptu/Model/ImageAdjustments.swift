// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

struct AdjustmentColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ color: RGBA) {
        self.init(red: PixelMath.unit(color.r), green: PixelMath.unit(color.g), blue: PixelMath.unit(color.b))
    }

    var clamped: Self {
        Self(
            red: PixelMath.clamp(red, 0...1, 0),
            green: PixelMath.clamp(green, 0...1, 0),
            blue: PixelMath.clamp(blue, 0...1, 0)
        )
    }

    var rgba: RGBA {
        let color = clamped
        return RGBA(r: PixelMath.byte(color.red), g: PixelMath.byte(color.green), b: PixelMath.byte(color.blue), a: 255)
    }
}

struct ExposureSettings: Codable, Equatable, Sendable {
    static let exposureRange: ClosedRange<Double> = -20...20
    static let offsetRange: ClosedRange<Double> = -0.5...0.5
    static let gammaRange: ClosedRange<Double> = 0.01...9.99

    var exposure: Double = 0
    var offset: Double = 0
    var gamma: Double = 1

    var isIdentity: Bool { exposure == 0 && offset == 0 && gamma == 1 }

    var normalized: Self {
        var copy = self
        copy.exposure = PixelMath.clamp(exposure, Self.exposureRange, 0)
        copy.offset = PixelMath.clamp(offset, Self.offsetRange, 0)
        copy.gamma = PixelMath.clamp(gamma, Self.gammaRange, 1)
        return copy
    }

    var table: [UInt8] {
        let scale = pow(2, exposure)
        return (0...255).map { index in
            let encoded = Double(index) / 255
            var linear = PixelMath.srgbToLinear(encoded)
            linear = pow(max(0, linear * scale + offset), 1 / gamma)
            return PixelMath.byte(PixelMath.linearToSRGB(linear))
        }
    }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        let settings = normalized
        guard !settings.isIdentity else { return buffer }
        let table = settings.table
        var result = buffer
        result.updateEach { _, _, pixel in
            guard pixel.a > 0 else { return }
            pixel.r = table[Int(pixel.r)]
            pixel.g = table[Int(pixel.g)]
            pixel.b = table[Int(pixel.b)]
        }
        return result
    }
}

struct GradientMapSettings: Codable, Equatable, Sendable {
    var shadows = AdjustmentColor(red: 0, green: 0, blue: 0)
    var highlights = AdjustmentColor(red: 1, green: 1, blue: 1)
    var reversed = false

    var normalized: Self {
        var result = self
        result.shadows = shadows.clamped
        result.highlights = highlights.clamped
        return result
    }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        let settings = normalized
        let dark = settings.reversed ? settings.highlights : settings.shadows
        let light = settings.reversed ? settings.shadows : settings.highlights
        var table = [UInt8]()
        table.reserveCapacity(256 * 3)
        for index in 0...255 {
            let t = Double(index) / 255
            table.append(PixelMath.byte(dark.red + (light.red - dark.red) * t))
            table.append(PixelMath.byte(dark.green + (light.green - dark.green) * t))
            table.append(PixelMath.byte(dark.blue + (light.blue - dark.blue) * t))
        }
        var result = buffer
        result.updateEach { _, _, pixel in
            guard pixel.a > 0 else { return }
            let r = Int(pixel.r)
            let g = Int(pixel.g)
            let b = Int(pixel.b)
            let level = min(255, (2126 * r + 7152 * g + 722 * b + 5000) / 10000)
            let base = level * 3
            pixel.r = table[base]
            pixel.g = table[base + 1]
            pixel.b = table[base + 2]
        }
        return result
    }
}

struct BlackWhiteSettings: Codable, Equatable, Sendable {
    static let range: ClosedRange<Double> = -200...300
    var reds: Double = 40
    var yellows: Double = 60
    var greens: Double = 40
    var cyans: Double = 60
    var blues: Double = 20
    var magentas: Double = 80
    var tint = false
    var tintHue: Double = 40
    var tintSaturation: Double = 20

    var normalized: Self {
        var result = self
        result.reds = PixelMath.clamp(reds, Self.range, 40)
        result.yellows = PixelMath.clamp(yellows, Self.range, 60)
        result.greens = PixelMath.clamp(greens, Self.range, 40)
        result.cyans = PixelMath.clamp(cyans, Self.range, 60)
        result.blues = PixelMath.clamp(blues, Self.range, 20)
        result.magentas = PixelMath.clamp(magentas, Self.range, 80)
        result.tintHue = PixelMath.clamp(tintHue, 0...360, 40)
        result.tintSaturation = PixelMath.clamp(tintSaturation, 0...100, 20)
        return result
    }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        let settings = normalized
        let weights = [settings.reds, settings.yellows, settings.greens, settings.cyans, settings.blues, settings.magentas]
            .map { $0 / 100 }
        return PixelMath.mapColors(buffer) { r, g, b, _, _ in
            let high = max(r, g, b)
            let low = min(r, g, b)
            let mid = r + g + b - high - low
            let primary: Int
            let secondary: Int
            if high == r {
                primary = 0
                secondary = g >= b ? 1 : 5
            } else if high == g {
                primary = 2
                secondary = r >= b ? 1 : 3
            } else {
                primary = 4
                secondary = g >= r ? 3 : 5
            }
            var gray = low + (mid - low) * weights[secondary] + (high - mid) * weights[primary]
            gray = PixelMath.clampUnit(gray)
            if settings.tint && settings.tintSaturation > 0 {
                let tinted = PixelMath.hslToRGB(h: settings.tintHue, s: settings.tintSaturation / 100, l: gray)
                r = tinted.r
                g = tinted.g
                b = tinted.b
            } else {
                r = gray
                g = gray
                b = gray
            }
        }
    }
}

struct ColorBalanceSettings: Codable, Equatable, Sendable {
    static let range: ClosedRange<Double> = -100...100
    var shadowCyanRed: Double = 0
    var shadowMagentaGreen: Double = 0
    var shadowYellowBlue: Double = 0
    var midCyanRed: Double = 0
    var midMagentaGreen: Double = 0
    var midYellowBlue: Double = 0
    var highlightCyanRed: Double = 0
    var highlightMagentaGreen: Double = 0
    var highlightYellowBlue: Double = 0
    var preserveLuminosity = true

    var isIdentity: Bool {
        [shadowCyanRed, shadowMagentaGreen, shadowYellowBlue,
         midCyanRed, midMagentaGreen, midYellowBlue,
         highlightCyanRed, highlightMagentaGreen, highlightYellowBlue].allSatisfy { $0 == 0 }
    }

    var normalized: Self {
        var result = self
        result.shadowCyanRed = PixelMath.clamp(shadowCyanRed, Self.range, 0)
        result.shadowMagentaGreen = PixelMath.clamp(shadowMagentaGreen, Self.range, 0)
        result.shadowYellowBlue = PixelMath.clamp(shadowYellowBlue, Self.range, 0)
        result.midCyanRed = PixelMath.clamp(midCyanRed, Self.range, 0)
        result.midMagentaGreen = PixelMath.clamp(midMagentaGreen, Self.range, 0)
        result.midYellowBlue = PixelMath.clamp(midYellowBlue, Self.range, 0)
        result.highlightCyanRed = PixelMath.clamp(highlightCyanRed, Self.range, 0)
        result.highlightMagentaGreen = PixelMath.clamp(highlightMagentaGreen, Self.range, 0)
        result.highlightYellowBlue = PixelMath.clamp(highlightYellowBlue, Self.range, 0)
        return result
    }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        let settings = normalized
        guard !settings.isIdentity else { return buffer }
        let shadows = [settings.shadowCyanRed, settings.shadowMagentaGreen, settings.shadowYellowBlue].map { $0 / 100 }
        let midtones = [settings.midCyanRed, settings.midMagentaGreen, settings.midYellowBlue].map { $0 / 100 }
        let highlights = [settings.highlightCyanRed, settings.highlightMagentaGreen, settings.highlightYellowBlue].map { $0 / 100 }
        return PixelMath.mapColors(buffer) { r, g, b, _, _ in
            let before = 0.299 * r + 0.587 * g + 0.114 * b
            var channels = [r, g, b]
            for index in 0..<3 {
                let weights = tonalWeights(channels[index])
                channels[index] += shadows[index] * weights.shadow + midtones[index] * weights.mid + highlights[index] * weights.highlight
                channels[index] = PixelMath.clampUnit(channels[index])
            }
            if settings.preserveLuminosity {
                let after = 0.299 * channels[0] + 0.587 * channels[1] + 0.114 * channels[2]
                if after > 0.0001 {
                    let ratio = before / after
                    for index in 0..<3 {
                        channels[index] = PixelMath.clampUnit(channels[index] * ratio)
                    }
                }
            }
            r = channels[0]
            g = channels[1]
            b = channels[2]
        }
    }

    private func tonalWeights(_ value: Double) -> (shadow: Double, mid: Double, highlight: Double) {
        let a = 0.25
        let b = 0.333
        let scale = 0.7
        let shadow = min(1, max(0, (value - b) / -a + 0.5)) * scale
        let highlight = min(1, max(0, (value + b - 1) / a + 0.5)) * scale
        let mid1 = min(1, max(0, (value - b) / a + 0.5))
        let mid2 = min(1, max(0, (value + b - 1) / -a + 0.5))
        return (shadow, mid1 * mid2 * scale, highlight)
    }
}

struct GrainSettings: Codable, Equatable, Sendable {
    static let amountRange: ClosedRange<Double> = 0...100
    static let sizeRange: ClosedRange<Double> = 0.5...20
    static let roughnessRange: ClosedRange<Double> = 0...100

    var amount: Double = 25
    var size: Double = 1.5
    var roughness: Double = 50
    var seed: UInt32 = 0

    var normalized: Self {
        var result = self
        result.amount = PixelMath.clamp(amount, Self.amountRange, 25)
        result.size = PixelMath.clamp(size, Self.sizeRange, 1.5)
        result.roughness = PixelMath.clamp(roughness, Self.roughnessRange, 50)
        return result
    }

    func apply(_ buffer: PixelBuffer, originX: Double = 0, originY: Double = 0, unitsPerPixel: Double = 1) -> PixelBuffer {
        let settings = normalized
        guard settings.amount > 0, unitsPerPixel > 0 else { return buffer }
        let size = settings.size > 0 ? settings.size : 1
        let strength = (settings.amount > 100 ? 1 : settings.amount / 100) * 0.35 * 255
        let rough = settings.roughness / 100
        let fineSeed = mix32(settings.seed ^ 0xA511E9B3)
        let detailSize = max(0.5, size * 0.35)
        return PixelMath.mapColors(buffer) { r, g, b, x, y in
            let u = originX + (Double(x) + 0.5) * unitsPerPixel
            let v = originY + (Double(y) + 0.5) * unitsPerPixel
            let smooth = grainField(u, v, scale: size, seed: settings.seed)
            let fine = grainField(u, v, scale: detailSize, seed: fineSeed)
            let noise = smooth + (fine - smooth) * Float(rough)
            let level = PixelMath.clampUnit(PixelMath.rec709(r, g, b))
            let delta = Double(noise) * strength * (0.4 + 2.4 * level * (1 - level)) / 255
            r = PixelMath.clampUnit(r + delta)
            g = PixelMath.clampUnit(g + delta)
            b = PixelMath.clampUnit(b + delta)
        }
    }

    private func mix32(_ value: UInt32) -> UInt32 {
        var x = value
        x ^= x >> 16
        x &*= 0x7feb352d
        x ^= x >> 15
        x &*= 0x846ca68b
        x ^= x >> 16
        return x
    }

    private func lattice(_ ix: Int, _ iy: Int, seed: UInt32) -> Float {
        let mixed = mix32(UInt32(bitPattern: Int32(truncatingIfNeeded: ix)) &* 0x9E3779B1 ^ mix32(UInt32(bitPattern: Int32(truncatingIfNeeded: iy)) &* 0x85EBCA77 ^ seed))
        return Float(mixed & 0xFFFF) / 65535 + Float(mixed >> 16) / 65535 - 1
    }

    private func grainField(_ u: Double, _ v: Double, scale: Double, seed: UInt32) -> Float {
        let cellX = floor(u / scale)
        let cellY = floor(v / scale)
        var tx = Float(u / scale - cellX)
        var ty = Float(v / scale - cellY)
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        let ix = Int(cellX)
        let iy = Int(cellY)
        let n00 = lattice(ix, iy, seed: seed)
        let n10 = lattice(ix + 1, iy, seed: seed)
        let n01 = lattice(ix, iy + 1, seed: seed)
        let n11 = lattice(ix + 1, iy + 1, seed: seed)
        let top = n00 + (n10 - n00) * tx
        let bottom = n01 + (n11 - n01) * tx
        return (top + (bottom - top) * ty) * 1.6
    }
}

enum InvertAdjustment {
    static func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        var result = buffer
        result.updateEach { _, _, pixel in
            guard pixel.a > 0 else { return }
            pixel.r = 255 - pixel.r
            pixel.g = 255 - pixel.g
            pixel.b = 255 - pixel.b
        }
        return result
    }
}
