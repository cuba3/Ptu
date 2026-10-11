// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreImage
import Foundation

enum FilterKind: String, CaseIterable, Sendable, Codable, Identifiable {
    case gaussianBlur
    case motionBlur
    case addNoise
    case vignette
    case bloomGlow
    case dither
    case tonalContrast
    case lensCorrection
    case invert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gaussianBlur: L10n.Filter.gaussianBlur
        case .motionBlur: L10n.Filter.motionBlur
        case .addNoise: L10n.Filter.addNoise
        case .vignette: L10n.Filter.vignette
        case .bloomGlow: L10n.Filter.bloom
        case .dither: L10n.Filter.dither
        case .tonalContrast: L10n.Filter.tonalContrast
        case .lensCorrection: L10n.Filter.lensCorrection
        case .invert: L10n.Filter.invert
        }
    }
}

struct FilterSettings: Equatable, Sendable, Codable {
    var radius: Double = 1
    var angle: Double = 0
    var distance: Double = 10
    var amount: Double = 10
    var gaussian = false
    var monochromatic = false
    var seed: UInt32 = 0
    var vignetteAmount: Double = 35
    var vignetteColor = AdjustmentColor(red: 0, green: 0, blue: 0)
    var vignetteMidpoint: Double = 50
    var vignetteRoundness: Double = 100
    var vignetteFeather: Double = 60
    var vignetteHighlights: Double = 25
    var bloomAmount: Double = 40
    var bloomRadius: Double = 24
    var tonalAmount: Double = 50
    var tonalRadius: Double = 16
    var tonalShadows: Double = 40
    var tonalMidtones: Double = 60
    var tonalHighlights: Double = 30
    var distortion: Double = 0
    var dither = DitherSettings()

    var normalized: Self {
        var result = self
        result.radius = PixelMath.clamp(radius, 0.1...250, 1)
        result.angle = PixelMath.clamp(angle, -90...90, 0)
        result.distance = PixelMath.clamp(distance, 1...2000, 10)
        result.amount = PixelMath.clamp(amount, 0.1...400, 10)
        result.vignetteAmount = PixelMath.clamp(vignetteAmount, 0...100, 35)
        result.vignetteColor = vignetteColor.clamped
        result.vignetteMidpoint = PixelMath.clamp(vignetteMidpoint, 0...100, 50)
        result.vignetteRoundness = PixelMath.clamp(vignetteRoundness, -100...100, 100)
        result.vignetteFeather = PixelMath.clamp(vignetteFeather, 0...100, 60)
        result.vignetteHighlights = PixelMath.clamp(vignetteHighlights, 0...100, 25)
        result.bloomAmount = PixelMath.clamp(bloomAmount, 0...100, 40)
        result.bloomRadius = PixelMath.clamp(bloomRadius, 1...150, 24)
        result.tonalAmount = PixelMath.clamp(tonalAmount, 0...100, 50)
        result.tonalRadius = PixelMath.clamp(tonalRadius, 1...100, 16)
        result.tonalShadows = PixelMath.clamp(tonalShadows, -100...100, 40)
        result.tonalMidtones = PixelMath.clamp(tonalMidtones, -100...100, 60)
        result.tonalHighlights = PixelMath.clamp(tonalHighlights, -100...100, 30)
        result.distortion = PixelMath.clamp(distortion, -100...100, 0)
        result.dither = dither.normalized
        return result
    }
}

enum PixelFilter {
    /// Photoshop's even streak of length d spreads about d / √12. Core Image's motion blur uses that as its radius.
    static let motionRadiusPerPixel = 1 / 12.0.squareRoot()
    static let lensStrength = 0.35

    private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    ])

    static func apply(_ kind: FilterKind, to buffer: PixelBuffer, settings: FilterSettings) -> PixelBuffer {
        let settings = settings.normalized
        switch kind {
        case .invert:
            return InvertAdjustment.apply(buffer)
        case .gaussianBlur:
            return render(buffer.applyingGaussianBlur(sigma: settings.radius), matching: buffer)
        case .motionBlur:
            return render(
                buffer.applyingMotionBlur(radius: settings.distance * motionRadiusPerPixel, angle: settings.angle),
                matching: buffer
            )
        case .addNoise:
            return addNoise(buffer, settings: settings)
        case .vignette:
            return vignette(buffer, settings: settings)
        case .bloomGlow:
            return render(
                buffer.applyingBloom(radius: settings.bloomRadius, intensity: settings.bloomAmount / 50),
                matching: buffer
            )
        case .dither:
            return settings.dither.apply(buffer)
        case .tonalContrast:
            return tonalContrast(buffer, settings: settings)
        case .lensCorrection:
            return lensDistort(buffer, k: settings.distortion / 100 * lensStrength)
        }
    }

    static func render(_ image: CIImage?, matching buffer: PixelBuffer) -> PixelBuffer {
        guard let image else { return buffer }
        let extent = CGRect(x: 0, y: 0, width: buffer.width, height: buffer.height)
        guard let rendered = context.createCGImage(image, from: extent),
              let pixels = PixelBuffer.from(cgImage: rendered) else { return buffer }
        return pixels
    }

    static func lensDistort(_ buffer: PixelBuffer, k: Double) -> PixelBuffer {
        guard k != 0, buffer.width > 0, buffer.height > 0 else { return buffer }
        let source = buffer.copyBytes()
        var destination = [UInt8](repeating: 0, count: source.count)
        let width = buffer.width
        let height = buffer.height
        let cx = Double(width) * 0.5
        let cy = Double(height) * 0.5
        let halfDiagonal2 = cx * cx + cy * cy
        for y in 0..<height {
            let dy = Double(y) + 0.5 - cy
            for x in 0..<width {
                let dx = Double(x) + 0.5 - cx
                let scale = 1 - k * (dx * dx + dy * dy) / halfDiagonal2
                let sx = cx + dx * scale - 0.5
                let sy = cy + dy * scale - 0.5
                let x0 = Int(floor(sx))
                let y0 = Int(floor(sy))
                let fx = sx - Double(x0)
                let fy = sy - Double(y0)
                var sums = [0.0, 0.0, 0.0, 0.0]
                for j in 0..<2 {
                    let row = y0 + j
                    guard row >= 0, row < height else { continue }
                    let wy = j == 0 ? 1 - fy : fy
                    guard wy != 0 else { continue }
                    for i in 0..<2 {
                        let column = x0 + i
                        guard column >= 0, column < width else { continue }
                        let weight = wy * (i == 0 ? 1 - fx : fx)
                        guard weight != 0 else { continue }
                        let pixel = (row * width + column) * 4
                        for channel in 0..<4 {
                            sums[channel] += weight * Double(source[pixel + channel])
                        }
                    }
                }
                let out = (y * width + x) * 4
                for channel in 0..<4 {
                    destination[out + channel] = UInt8(clamping: Int(sums[channel].rounded()))
                }
            }
        }
        var result = buffer
        result.setBytes(destination)
        return result
    }

    private static func addNoise(_ buffer: PixelBuffer, settings: FilterSettings) -> PixelBuffer {
        let spread = settings.amount / 100 * 127.5
        var result = buffer
        result.updateEach { x, y, pixel in
            guard pixel.a > 0 else { return }
            let base = noiseHash(settings.seed ^ noiseHash(UInt32(x) &* 0x9e3779b9 ^ noiseHash(UInt32(y) &* 0x85ebca6b)))
            for channel in 0..<3 {
                let key = settings.monochromatic ? base : base &+ UInt32(channel) &* 0x9e3779b9
                let n: Float
                if settings.gaussian {
                    let u1 = noiseUnit(key)
                    let u2 = noiseUnit(key ^ 0x68e31da4)
                    n = sqrt(-2 * log(1 - u1)) * cos(2 * Float.pi * u2) * Float(spread) * (2 / 3)
                } else {
                    n = (noiseUnit(key) * 2 - 1) * Float(spread)
                }
                let current: UInt8
                switch channel {
                case 0: current = pixel.r
                case 1: current = pixel.g
                default: current = pixel.b
                }
                let value = min(255, max(0, Float(current) + n))
                let byte = UInt8(clamping: Int(value.rounded()))
                switch channel {
                case 0: pixel.r = byte
                case 1: pixel.g = byte
                default: pixel.b = byte
                }
            }
        }
        return result
    }

    private static func noiseHash(_ value: UInt32) -> UInt32 {
        var x = value
        x ^= x >> 16
        x &*= 0x7feb352d
        x ^= x >> 15
        x &*= 0x846ca68b
        x ^= x >> 16
        return x
    }

    private static func noiseUnit(_ key: UInt32) -> Float {
        Float(noiseHash(key) >> 8) * (1 / 16_777_216)
    }

    private static func vignette(_ buffer: PixelBuffer, settings: FilterSettings) -> PixelBuffer {
        guard settings.vignetteAmount > 0 else { return buffer }
        let color = settings.vignetteColor
        return PixelMath.mapColors(buffer) { r, g, b, x, y in
            let mask = CameraRawPixels.vignetteMask(
                x: x, y: y, width: buffer.width, height: buffer.height,
                midpoint: settings.vignetteMidpoint, roundness: settings.vignetteRoundness, feather: settings.vignetteFeather
            )
            let bright = PixelMath.clampUnit((PixelMath.rec709(r, g, b) - 0.45) / 0.55)
            let effect = PixelMath.clampUnit(settings.vignetteAmount / 100) * mask * (1 - (settings.vignetteHighlights / 100) * bright)
            r += (color.red - r) * effect
            g += (color.green - g) * effect
            b += (color.blue - b) * effect
        }
    }

    private static func tonalContrast(_ buffer: PixelBuffer, settings: FilterSettings) -> PixelBuffer {
        guard settings.tonalAmount > 0, settings.tonalShadows != 0 || settings.tonalMidtones != 0 || settings.tonalHighlights != 0 else {
            return buffer
        }
        let blurred = render(buffer.applyingGaussianBlur(sigma: settings.tonalRadius), matching: buffer)
        let strength = settings.tonalAmount / 50
        return PixelMath.mapColors(buffer) { r, g, b, x, y in
            let base = blurred.pixel(x: x, y: y)
            guard base.a > 0 else { return }
            let lum = PixelMath.rec709(r, g, b)
            let baseLum = PixelMath.rec709(PixelMath.unit(base.r), PixelMath.unit(base.g), PixelMath.unit(base.b))
            let shadowWeight = 1 - smooth(0.15, 0.5, baseLum)
            let highlightWeight = smooth(0.5, 0.85, baseLum)
            let midtoneWeight = 1 - shadowWeight - highlightWeight
            let weight = (settings.tonalShadows * shadowWeight + settings.tonalMidtones * midtoneWeight + settings.tonalHighlights * highlightWeight) / 100
            let detail = lum - baseLum
            let delta = 0.18 * tanh(detail * 6) * weight * strength * (4 * lum * (1 - lum))
            r = PixelMath.clampUnit(r + delta)
            g = PixelMath.clampUnit(g + delta)
            b = PixelMath.clampUnit(b + delta)
        }
    }

    private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = PixelMath.clampUnit((value - low) / (high - low))
        return t * t * (3 - 2 * t)
    }
}

private extension PixelBuffer {
    func applyingGaussianBlur(sigma: Double) -> CIImage? {
        guard let image = cgImage() else { return nil }
        return CIImage(cgImage: image).clampedToExtent().applyingGaussianBlur(sigma: sigma)
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func applyingMotionBlur(radius: Double, angle: Double) -> CIImage? {
        guard let image = cgImage() else { return nil }
        return CIImage(cgImage: image).clampedToExtent().applyingFilter("CIMotionBlur", parameters: [
            kCIInputRadiusKey: radius,
            kCIInputAngleKey: angle * .pi / 180,
        ]).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func applyingBloom(radius: Double, intensity: Double) -> CIImage? {
        guard let image = cgImage() else { return nil }
        return CIImage(cgImage: image).applyingFilter("CIBloom", parameters: [
            kCIInputRadiusKey: radius,
            kCIInputIntensityKey: intensity,
        ]).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }
}
