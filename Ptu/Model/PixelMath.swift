// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

/// Shared straight-sRGB helpers. PixelBuffer stores straight alpha, so these
/// routines read and write 0…1 color channels and leave coverage separate.
enum PixelMath {
    static func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }

    static func clampUnit(_ value: Double) -> Double {
        if !value.isFinite { return 0 }
        return min(1, max(0, value))
    }

    static func byte(_ value: Double) -> UInt8 {
        UInt8(clamping: Int((clampUnit(value) * 255).rounded()))
    }

    static func unit(_ byte: UInt8) -> Double {
        Double(byte) / 255
    }

    static func srgbToLinear(_ encoded: Double) -> Double {
        let encoded = clampUnit(encoded)
        if encoded <= 0.04045 { return encoded / 12.92 }
        return pow((encoded + 0.055) / 1.055, 2.4)
    }

    static func linearToSRGB(_ linear: Double) -> Double {
        let linear = clampUnit(linear)
        if linear <= 0.0031308 { return linear * 12.92 }
        return 1.055 * pow(linear, 1 / 2.4) - 0.055
    }

    static func rec709(_ r: Double, _ g: Double, _ b: Double) -> Double {
        0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    static func scaleLuminance(_ r: inout Double, _ g: inout Double, _ b: inout Double, target: Double) {
        let target = clampUnit(target)
        let y = rec709(r, g, b)
        if abs(target - y) < 1e-8 { return }
        if y < 1e-8 {
            if target > y { r = target; g = target; b = target }
            return
        }
        let scale = target / y
        r = clampUnit(r * scale)
        g = clampUnit(g * scale)
        b = clampUnit(b * scale)
    }

    static func rgbToHSL(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, l: Double) {
        let high = max(r, g, b)
        let low = min(r, g, b)
        let lightness = (high + low) / 2
        let delta = high - low
        guard delta > 1e-8 else { return (0, 0, lightness) }
        let saturation = delta / (1 - abs(2 * lightness - 1))
        let hue: Double
        if high == r {
            hue = (g - b) / delta
        } else if high == g {
            hue = (b - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        var degrees = hue * 60
        if degrees < 0 { degrees += 360 }
        return (degrees, min(1, max(0, saturation)), lightness)
    }

    static func hslToRGB(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        let saturation = clampUnit(s)
        let lightness = clampUnit(l)
        guard saturation > 1e-8 else { return (lightness, lightness, lightness) }
        var hue = h.truncatingRemainder(dividingBy: 360)
        if hue < 0 { hue += 360 }
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let sector = hue / 60
        let second = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let base = lightness - chroma / 2
        let rgb: (Double, Double, Double)
        switch Int(sector) {
        case 0: rgb = (chroma, second, 0)
        case 1: rgb = (second, chroma, 0)
        case 2: rgb = (0, chroma, second)
        case 3: rgb = (0, second, chroma)
        case 4: rgb = (second, 0, chroma)
        default: rgb = (chroma, 0, second)
        }
        return (clampUnit(rgb.0 + base), clampUnit(rgb.1 + base), clampUnit(rgb.2 + base))
    }

    /// HSL with hue in 0…1, matching the Camera Raw curve kernel.
    static func rgbToHSLUnit(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, l: Double) {
        let hsl = rgbToHSL(r, g, b)
        return (hsl.h / 360, hsl.s, hsl.l)
    }

    static func hslUnitToRGB(_ h: Double, _ s: Double, _ l: Double) -> (r: Double, g: Double, b: Double) {
        hslToRGB(h: h * 360, s: s, l: l)
    }

    static func mapColors(_ buffer: PixelBuffer, _ body: (_ r: inout Double, _ g: inout Double, _ b: inout Double, _ x: Int, _ y: Int) -> Void) -> PixelBuffer {
        var result = buffer
        result.updateEach { x, y, pixel in
            guard pixel.a > 0 else { return }
            var r = unit(pixel.r)
            var g = unit(pixel.g)
            var b = unit(pixel.b)
            body(&r, &g, &b, x, y)
            pixel.r = byte(r)
            pixel.g = byte(g)
            pixel.b = byte(b)
        }
        return result
    }

    /// Edge-clamped box blur of a scalar plane. `radius` < 1 copies the source.
    static func boxBlur(_ source: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        guard width > 0, height > 0, source.count == width * height else { return source }
        guard radius >= 1 else { return source }
        let window = radius * 2 + 1
        var temp = [Float](repeating: 0, count: source.count)
        var destination = [Float](repeating: 0, count: source.count)
        func clamped(_ index: Int, _ limit: Int) -> Int {
            min(max(index, 0), limit - 1)
        }
        for y in 0..<height {
            var sum = 0.0
            for k in -radius...radius {
                sum += Double(source[y * width + clamped(k, width)])
            }
            for x in 0..<width {
                temp[y * width + x] = Float(sum / Double(window))
                sum += Double(source[y * width + clamped(x + radius + 1, width)])
                sum -= Double(source[y * width + clamped(x - radius, width)])
            }
        }
        for x in 0..<width {
            var sum = 0.0
            for k in -radius...radius {
                sum += Double(temp[clamped(k, height) * width + x])
            }
            for y in 0..<height {
                destination[y * width + x] = Float(sum / Double(window))
                sum += Double(temp[clamped(y + radius + 1, height) * width + x])
                sum -= Double(temp[clamped(y - radius, height) * width + x])
            }
        }
        return destination
    }

    static func lumaPlane(_ buffer: PixelBuffer) -> [Float] {
        var plane = [Float](repeating: 0, count: buffer.width * buffer.height)
        var index = 0
        for y in 0..<buffer.height {
            for x in 0..<buffer.width {
                let pixel = buffer.pixel(x: x, y: y)
                if pixel.a == 0 {
                    plane[index] = 0
                } else {
                    plane[index] = Float(rec709(unit(pixel.r), unit(pixel.g), unit(pixel.b)))
                }
                index += 1
            }
        }
        return plane
    }
}
