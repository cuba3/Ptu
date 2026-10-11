// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

enum DitherStyle: String, CaseIterable, Sendable, Codable, Identifiable {
    case atkinson
    case floydSteinberg
    case bayer2
    case bayer4
    case bayer8
    case dots
    case lines
    case diamonds
    case patterns
    case scanlines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atkinson: L10n.Dither.atkinson
        case .floydSteinberg: L10n.Dither.floyd
        case .bayer2: L10n.Dither.bayer2
        case .bayer4: L10n.Dither.bayer4
        case .bayer8: L10n.Dither.bayer8
        case .dots: L10n.Dither.dots
        case .lines: L10n.Dither.lines
        case .diamonds: L10n.Dither.diamonds
        case .patterns: L10n.Dither.patterns
        case .scanlines: L10n.Dither.scanlines
        }
    }

    var diffuses: Bool { self == .atkinson || self == .floydSteinberg }
    var hasTones: Bool { diffuses || self == .bayer2 || self == .bayer4 || self == .bayer8 }
}

enum DitherColors: String, CaseIterable, Sendable, Codable, Identifiable {
    case blackWhite
    case twoColors
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blackWhite: L10n.Dither.blackWhite
        case .twoColors: L10n.Dither.twoColors
        case .original: L10n.Dither.original
        }
    }
}

struct DitherSettings: Equatable, Sendable, Codable {
    var style: DitherStyle = .floydSteinberg
    var pixelSize: Double = 2
    var levels: Double = 2
    var diffusion: Double = 100
    var density: Double = 0
    var contrast: Double = 0
    var colors: DitherColors = .blackWhite
    var dark = AdjustmentColor(red: 0, green: 0, blue: 0)
    var light = AdjustmentColor(red: 1, green: 1, blue: 1)
    var cellSize: Double = 8
    var angle: Double = 45
    var lineSpacing: Double = 4

    var normalized: Self {
        var result = self
        result.pixelSize = PixelMath.clamp(pixelSize, 1...32, 2).rounded()
        result.levels = PixelMath.clamp(levels, 2...8, 2).rounded()
        result.diffusion = PixelMath.clamp(diffusion, 0...100, 100)
        result.density = PixelMath.clamp(density, -100...100, 0)
        result.contrast = PixelMath.clamp(contrast, -100...100, 0)
        result.dark = dark.clamped
        result.light = light.clamped
        result.cellSize = PixelMath.clamp(cellSize, 4...64, 8).rounded()
        result.angle = PixelMath.clamp(angle, -90...90, 45)
        result.lineSpacing = PixelMath.clamp(lineSpacing, 2...32, 4).rounded()
        return result
    }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        let settings = normalized
        let block = max(1, Int(settings.pixelSize))
        let working = block > 1 ? downsample(buffer, block: block) : buffer
        let dithered = dither(working, settings: settings)
        guard block > 1 else { return dithered }
        return upsample(dithered, block: block, width: buffer.width, height: buffer.height)
    }

    private func downsample(_ buffer: PixelBuffer, block: Int) -> PixelBuffer {
        let width = max(1, (buffer.width + block - 1) / block)
        let height = max(1, (buffer.height + block - 1) / block)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                var r = 0
                var g = 0
                var b = 0
                var a = 0
                var count = 0
                for dy in 0..<block {
                    for dx in 0..<block {
                        let sx = x * block + dx
                        let sy = y * block + dy
                        guard sx < buffer.width, sy < buffer.height else { continue }
                        let pixel = buffer.pixel(x: sx, y: sy)
                        r += Int(pixel.r)
                        g += Int(pixel.g)
                        b += Int(pixel.b)
                        a += Int(pixel.a)
                        count += 1
                    }
                }
                guard count > 0 else { continue }
                let index = (y * width + x) * 4
                bytes[index] = UInt8(r / count)
                bytes[index + 1] = UInt8(g / count)
                bytes[index + 2] = UInt8(b / count)
                bytes[index + 3] = UInt8(a / count)
            }
        }
        return PixelBuffer(bytes: bytes, width: width, height: height)
    }

    private func upsample(_ buffer: PixelBuffer, block: Int, width: Int, height: Int) -> PixelBuffer {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let pixel = buffer.pixel(x: x / block, y: y / block)
                let index = (y * width + x) * 4
                bytes[index] = pixel.r
                bytes[index + 1] = pixel.g
                bytes[index + 2] = pixel.b
                bytes[index + 3] = pixel.a
            }
        }
        return PixelBuffer(bytes: bytes, width: width, height: height)
    }

    private func dither(_ buffer: PixelBuffer, settings: DitherSettings) -> PixelBuffer {
        let width = buffer.width
        let height = buffer.height
        var tone = [Float](repeating: 0, count: width * height)
        var alpha = [UInt8](repeating: 0, count: width * height)
        var colors = [(r: Float, g: Float, b: Float)](repeating: (0, 0, 0), count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let pixel = buffer.pixel(x: x, y: y)
                let index = y * width + x
                alpha[index] = pixel.a
                guard pixel.a > 0 else { continue }
                var value = Float(PixelMath.rec709(PixelMath.unit(pixel.r), PixelMath.unit(pixel.g), PixelMath.unit(pixel.b)))
                value = min(1, max(0, (value - 0.5) * Float(1 + settings.contrast / 100) + 0.5 - Float(settings.density / 100) * 0.5))
                tone[index] = value
                colors[index] = (Float(pixel.r), Float(pixel.g), Float(pixel.b))
            }
        }
        let steps = max(2, Int(settings.levels))
        let spread = Float(settings.diffusion / 100)
        switch settings.style {
        case .floydSteinberg:
            diffuse(tone: &tone, width: width, height: height, steps: steps, spread: spread, kernel: floyd)
        case .atkinson:
            diffuse(tone: &tone, width: width, height: height, steps: steps, spread: spread, kernel: atkinson)
        case .bayer2, .bayer4, .bayer8:
            let matrix = bayer(settings.style)
            quantizeOrdered(&tone, width: width, height: height, steps: steps, matrix: matrix)
        case .dots, .lines, .diamonds, .patterns:
            quantizeHalftone(&tone, width: width, height: height, settings: settings)
        case .scanlines:
            let spacing = max(2, Int(settings.lineSpacing))
            for index in tone.indices {
                let y = index / width
                if y % spacing != 0 { tone[index] = 0 } else { tone[index] = tone[index] >= 0.5 ? 1 : 0 }
            }
        }
        return paint(tone, alpha: alpha, colors: colors, width: width, height: height, settings: settings)
    }

    private var floyd: [(dx: Int, dy: Int, weight: Float)] {
        [(1, 0, 7 / 16), (-1, 1, 3 / 16), (0, 1, 5 / 16), (1, 1, 1 / 16)]
    }

    private var atkinson: [(dx: Int, dy: Int, weight: Float)] {
        [(1, 0, 1 / 8), (2, 0, 1 / 8), (-1, 1, 1 / 8), (0, 1, 1 / 8), (1, 1, 1 / 8), (0, 2, 1 / 8)]
    }

    private func diffuse(
        tone: inout [Float],
        width: Int,
        height: Int,
        steps: Int,
        spread: Float,
        kernel: [(dx: Int, dy: Int, weight: Float)]
    ) {
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let original = tone[index]
                let quantized = quantize(original, steps: steps)
                let error = (original - quantized) * spread
                tone[index] = quantized
                for tap in kernel {
                    let nx = x + tap.dx
                    let ny = y + tap.dy
                    guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                    tone[ny * width + nx] = min(1, max(0, tone[ny * width + nx] + error * tap.weight))
                }
            }
        }
    }

    private func quantize(_ value: Float, steps: Int) -> Float {
        guard steps > 1 else { return value >= 0.5 ? 1 : 0 }
        let scaled = min(Float(steps - 1), max(0, value * Float(steps - 1)))
        return scaled.rounded() / Float(steps - 1)
    }

    private func quantizeOrdered(_ tone: inout [Float], width: Int, height: Int, steps: Int, matrix: [Float]) {
        let side = Int(Double(matrix.count).squareRoot())
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let threshold = matrix[(y % side) * side + (x % side)] - 0.5
                let adjusted = min(1, max(0, tone[index] + threshold / Float(steps)))
                tone[index] = quantize(adjusted, steps: steps)
            }
        }
    }

    private func bayer(_ style: DitherStyle) -> [Float] {
        let n: Int
        switch style {
        case .bayer2: n = 2
        case .bayer4: n = 4
        default: n = 8
        }
        func cell(_ x: Int, _ y: Int, _ size: Int) -> Int {
            if size == 1 { return 0 }
            let half = size / 2
            let quadrant = (x >= half ? 1 : 0) + (y >= half ? 2 : 0)
            let offset = [0, 2, 3, 1][quadrant]
            return 4 * cell(x % half, y % half, half) + offset
        }
        return (0..<(n * n)).map { index in
            Float(cell(index % n, index / n, n) + 1) / Float(n * n + 1)
        }
    }

    private func quantizeHalftone(_ tone: inout [Float], width: Int, height: Int, settings: DitherSettings) {
        let cell = max(4, Int(settings.cellSize))
        let radians = settings.angle * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        for y in 0..<height {
            for x in 0..<width {
                let rx = Double(x) * cosine + Double(y) * sine
                let ry = Double(y) * cosine - Double(x) * sine
                let u = (rx.truncatingRemainder(dividingBy: Double(cell)) + Double(cell)).truncatingRemainder(dividingBy: Double(cell)) / Double(cell)
                let v = (ry.truncatingRemainder(dividingBy: Double(cell)) + Double(cell)).truncatingRemainder(dividingBy: Double(cell)) / Double(cell)
                let threshold: Double
                switch settings.style {
                case .lines:
                    threshold = abs(u - 0.5) * 2
                case .diamonds:
                    threshold = abs(u - 0.5) + abs(v - 0.5)
                case .patterns:
                    threshold = Double(((x / max(cell / 4, 1)) ^ (y / max(cell / 4, 1))) & 1)
                default:
                    threshold = hypot(u - 0.5, v - 0.5) * 2
                }
                let index = y * width + x
                tone[index] = Float(tone[index]) >= Float(threshold) ? 1 : 0
            }
        }
    }

    private func paint(
        _ tone: [Float],
        alpha: [UInt8],
        colors: [(r: Float, g: Float, b: Float)],
        width: Int,
        height: Int,
        settings: DitherSettings
    ) -> PixelBuffer {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let dark = settings.colors == .twoColors ? settings.dark : AdjustmentColor(red: 0, green: 0, blue: 0)
        let light = settings.colors == .twoColors ? settings.light : AdjustmentColor(red: 1, green: 1, blue: 1)
        for index in tone.indices {
            let pixel = index * 4
            bytes[pixel + 3] = alpha[index]
            guard alpha[index] > 0 else { continue }
            if settings.colors == .original {
                let scale = tone[index]
                bytes[pixel] = UInt8(clamping: Int(colors[index].r * scale))
                bytes[pixel + 1] = UInt8(clamping: Int(colors[index].g * scale))
                bytes[pixel + 2] = UInt8(clamping: Int(colors[index].b * scale))
            } else {
                let t = Double(min(1, max(0, tone[index])))
                bytes[pixel] = PixelMath.byte(dark.red + (light.red - dark.red) * t)
                bytes[pixel + 1] = PixelMath.byte(dark.green + (light.green - dark.green) * t)
                bytes[pixel + 2] = PixelMath.byte(dark.blue + (light.blue - dark.blue) * t)
            }
        }
        return PixelBuffer(bytes: bytes, width: width, height: height)
    }
}
