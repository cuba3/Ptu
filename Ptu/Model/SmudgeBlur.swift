// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum SmudgeMode: String, CaseIterable, Identifiable, Sendable {
    case smudge
    case liquify

    var id: String { rawValue }
}

/// Smudge carries the previous dab and mixes it down. Liquify pushes pixels along the stroke.
/// Both follow the CPU path in Compositor's `WarpStroke`.
enum SmudgeBlur {
    static func falloff(distance: Float, radius: Float, hardness: Float) -> Float {
        let u = distance / max(radius, 0.001)
        guard u < 1 else { return 0 }
        let edge = min(0.98, max(0, hardness))
        guard u > edge else { return 1 }
        let t = (1 - u) / (1 - edge)
        return t * t * (3 - 2 * t)
    }

    static func pickUp(buffer: PixelBuffer, center: CGPoint, radius: Int) -> [Float] {
        let side = radius * 2 + 1
        var carried = [Float](repeating: 0, count: side * side * 4)
        let cx = Int(center.x.rounded())
        let cy = Int(center.y.rounded())
        for dy in -radius...radius {
            let y = cy + dy
            guard y >= 0, y < buffer.height else { continue }
            for dx in -radius...radius {
                let x = cx + dx
                guard x >= 0, x < buffer.width else { continue }
                let pixel = buffer.pixel(x: x, y: y)
                let index = ((dy + radius) * side + dx + radius) * 4
                carried[index] = Float(pixel.r)
                carried[index + 1] = Float(pixel.g)
                carried[index + 2] = Float(pixel.b)
                carried[index + 3] = Float(pixel.a)
            }
        }
        return carried
    }

    static func smudge(buffer: inout PixelBuffer, carried: inout [Float], center: CGPoint, diameter: CGFloat, hardness: CGFloat, strength: CGFloat) {
        let radius = Int((diameter / 2).rounded(.up))
        let side = radius * 2 + 1
        guard carried.count == side * side * 4 else { return }
        let cx = Int(center.x.rounded())
        let cy = Int(center.y.rounded())
        let keep = Float(min(1, max(0.01, strength)))
        for dy in -radius...radius {
            let y = cy + dy
            guard y >= 0, y < buffer.height else { continue }
            for dx in -radius...radius {
                let x = cx + dx
                guard x >= 0, x < buffer.width else { continue }
                let falloff = Self.falloff(distance: Float(dx * dx + dy * dy).squareRoot(), radius: Float(diameter / 2), hardness: Float(hardness))
                guard falloff > 0 else { continue }
                let under = buffer.pixel(x: x, y: y)
                let index = ((dy + radius) * side + dx + radius) * 4
                let channels = [under.r, under.g, under.b, under.a]
                var mixed = [UInt8](repeating: 0, count: 4)
                for channel in 0..<4 {
                    let current = Float(channels[channel])
                    let painted = current + (carried[index + channel] - current) * falloff * keep
                    let byte = UInt8(clamping: Int(min(255, max(0, painted)).rounded()))
                    mixed[channel] = byte
                    carried[index + channel] = Float(byte)
                }
                buffer.setPixel(x: x, y: y, rgba: RGBA(r: mixed[0], g: mixed[1], b: mixed[2], a: mixed[3]))
            }
        }
    }

    static func push(buffer: inout PixelBuffer, from start: CGPoint, to end: CGPoint, diameter: CGFloat, hardness: CGFloat, strength: CGFloat) {
        let radius = Int((diameter / 2).rounded(.up))
        let moveX = Float(end.x - start.x) * Float(min(1, max(0.01, strength)))
        let moveY = Float(end.y - start.y) * Float(min(1, max(0.01, strength)))
        let margin = Int(ceil(max(abs(moveX), abs(moveY)))) + 2
        let cx = Int(end.x.rounded())
        let cy = Int(end.y.rounded())
        let x0 = max(0, cx - radius - margin)
        let x1 = min(buffer.width - 1, cx + radius + margin)
        let y0 = max(0, cy - radius - margin)
        let y1 = min(buffer.height - 1, cy + radius + margin)
        guard x0 <= x1, y0 <= y1 else { return }
        let copyWidth = x1 - x0 + 1
        let copyHeight = y1 - y0 + 1
        var scratch = [Float](repeating: 0, count: copyWidth * copyHeight * 4)
        for y in 0..<copyHeight {
            for x in 0..<copyWidth {
                let pixel = buffer.pixel(x: x + x0, y: y + y0)
                let index = (y * copyWidth + x) * 4
                scratch[index] = Float(pixel.r)
                scratch[index + 1] = Float(pixel.g)
                scratch[index + 2] = Float(pixel.b)
                scratch[index + 3] = Float(pixel.a)
            }
        }
        for dy in -radius...radius {
            let y = cy + dy
            guard y >= y0, y <= y1 else { continue }
            for dx in -radius...radius {
                let x = cx + dx
                guard x >= x0, x <= x1 else { continue }
                let falloff = Self.falloff(distance: Float(dx * dx + dy * dy).squareRoot(), radius: Float(diameter / 2), hardness: Float(hardness))
                guard falloff > 0 else { continue }
                let sampleX = min(Float(copyWidth - 1), max(0, Float(x - x0) - moveX * falloff))
                let sampleY = min(Float(copyHeight - 1), max(0, Float(y - y0) - moveY * falloff))
                let ix = min(copyWidth - 2, max(0, Int(sampleX)))
                let iy = min(copyHeight - 2, max(0, Int(sampleY)))
                let fx = sampleX - Float(ix)
                let fy = sampleY - Float(iy)
                let s00 = (iy * copyWidth + ix) * 4
                let s10 = s00 + 4
                let s01 = s00 + copyWidth * 4
                let s11 = s01 + 4
                var channels = [UInt8](repeating: 0, count: 4)
                for channel in 0..<4 {
                    let top = scratch[s00 + channel] + (scratch[s10 + channel] - scratch[s00 + channel]) * fx
                    let bottom = scratch[s01 + channel] + (scratch[s11 + channel] - scratch[s01 + channel]) * fx
                    channels[channel] = UInt8(clamping: Int(min(255, max(0, top + (bottom - top) * fy)).rounded()))
                }
                buffer.setPixel(x: x, y: y, rgba: RGBA(r: channels[0], g: channels[1], b: channels[2], a: channels[3]))
            }
        }
    }

    static func gaussian(_ buffer: PixelBuffer, sigma: CGFloat) -> PixelBuffer {
        guard sigma > 0.05 else { return buffer }
        let width = buffer.width
        let height = buffer.height
        let source = buffer.copyBytes()
        let blurred = gaussianRGBA(source, width: width, height: height, sigma: sigma)
        return PixelBuffer(bytes: blurred, width: width, height: height)
    }

    static func gaussianRGBA(_ source: [UInt8], width: Int, height: Int, sigma: CGFloat) -> [UInt8] {
        guard width > 0, height > 0, source.count == width * height * 4, sigma > 0.05 else { return source }
        let radius = min(48, max(1, Int(ceil(sigma * 2))))
        var kernel = [Float](repeating: 0, count: radius * 2 + 1)
        let sigma2 = Float(sigma * sigma)
        var weightSum: Float = 0
        for offset in -radius...radius {
            let weight = exp(-0.5 * Float(offset * offset) / max(sigma2, 0.0001))
            kernel[offset + radius] = weight
            weightSum += weight
        }
        for index in kernel.indices { kernel[index] /= weightSum }
        var horizontal = [Float](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                var sum = [Float](repeating: 0, count: 4)
                for offset in -radius...radius {
                    let sample = min(width - 1, max(0, x + offset))
                    let index = (y * width + sample) * 4
                    let weight = kernel[offset + radius]
                    for channel in 0..<4 { sum[channel] += Float(source[index + channel]) * weight }
                }
                let destination = (y * width + x) * 4
                for channel in 0..<4 { horizontal[destination + channel] = sum[channel] }
            }
        }
        var output = [UInt8](repeating: 0, count: width * height * 4)
        for x in 0..<width {
            for y in 0..<height {
                var sum = [Float](repeating: 0, count: 4)
                for offset in -radius...radius {
                    let sample = min(height - 1, max(0, y + offset))
                    let index = (sample * width + x) * 4
                    let weight = kernel[offset + radius]
                    for channel in 0..<4 { sum[channel] += horizontal[index + channel] * weight }
                }
                let destination = (y * width + x) * 4
                for channel in 0..<4 {
                    output[destination + channel] = UInt8(clamping: Int(min(255, max(0, sum[channel])).rounded()))
                }
            }
        }
        return output
    }
}
