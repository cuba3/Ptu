// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

/// Magic wand and color-range matching. The flood fill follows Compositor's scanline wand:
/// a seed run is filled, then one seed is pushed for each matching run on the rows above and below.
enum MagicWand {
    static func mask(
        in buffer: PixelBuffer,
        at point: CGPoint,
        tolerance: Int,
        contiguous: Bool,
        sampleRadius: Int = 0
    ) -> [UInt8]? {
        let width = buffer.width
        let height = buffer.height
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard point.x.isFinite, point.y.isFinite, (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        let bytes = buffer.copyBytes()
        let radius = max(0, sampleRadius)
        let x0 = max(0, x - radius)
        let x1 = min(width - 1, x + radius)
        let y0 = max(0, y - radius)
        let y1 = min(height - 1, y + radius)
        var sums = [0, 0, 0, 0]
        var samples = 0
        for sy in y0...y1 {
            for sx in x0...x1 {
                let index = (sy * width + sx) * 4
                for channel in 0..<4 { sums[channel] += Int(bytes[index + channel]) }
                samples += 1
            }
        }
        guard samples > 0 else { return nil }
        let reference = sums.map { ($0 + samples / 2) / samples }
        let limit = min(255, max(0, tolerance))
        var selected = [UInt8](repeating: 0, count: width * height)
        let count: Int
        if contiguous {
            count = flood(bytes: bytes, width: width, height: height, seedX: x, seedY: y, reference: reference, tolerance: limit, mask: &selected)
        } else {
            count = scan(bytes: bytes, width: width, height: height, reference: reference, tolerance: limit, mask: &selected)
        }
        guard count > 0 else { return nil }
        return selected
    }

    private static func matches(_ bytes: [UInt8], index: Int, reference: [Int], tolerance: Int) -> Bool {
        for channel in 0..<4 {
            let delta = Int(bytes[index + channel]) - reference[channel]
            if delta < -tolerance || delta > tolerance { return false }
        }
        return true
    }

    private static func scan(bytes: [UInt8], width: Int, height: Int, reference: [Int], tolerance: Int, mask: inout [UInt8]) -> Int {
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                if matches(bytes, index: index, reference: reference, tolerance: tolerance) {
                    mask[y * width + x] = 255
                    count += 1
                }
            }
        }
        return count
    }

    private static func flood(
        bytes: [UInt8],
        width: Int,
        height: Int,
        seedX: Int,
        seedY: Int,
        reference: [Int],
        tolerance: Int,
        mask: inout [UInt8]
    ) -> Int {
        var stack: [(Int, Int)] = [(seedX, seedY)]
        var count = 0
        while let (sx, sy) = stack.popLast() {
            let pixel = (sy * width + sx) * 4
            if mask[sy * width + sx] != 0 || !matches(bytes, index: pixel, reference: reference, tolerance: tolerance) {
                continue
            }
            var left = sx
            var right = sx
            while left > 0 {
                let index = (sy * width + left - 1) * 4
                if mask[sy * width + left - 1] != 0 || !matches(bytes, index: index, reference: reference, tolerance: tolerance) { break }
                left -= 1
            }
            while right + 1 < width {
                let index = (sy * width + right + 1) * 4
                if mask[sy * width + right + 1] != 0 || !matches(bytes, index: index, reference: reference, tolerance: tolerance) { break }
                right += 1
            }
            for x in left...right { mask[sy * width + x] = 255 }
            count += right - left + 1
            for side in [sy - 1, sy + 1] {
                guard side >= 0, side < height else { continue }
                var inRun = false
                for x in left...right {
                    let index = (side * width + x) * 4
                    let candidate = mask[side * width + x] == 0 && matches(bytes, index: index, reference: reference, tolerance: tolerance)
                    if candidate && !inRun { stack.append((x, side)) }
                    inRun = candidate
                }
            }
        }
        return count
    }
}

enum ColorRangeSelection {
    static func sampleColor(in buffer: PixelBuffer, at point: CGPoint) -> RGBA? {
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard point.x.isFinite, point.y.isFinite, (0..<buffer.width).contains(x), (0..<buffer.height).contains(y) else { return nil }
        var sums = [0, 0, 0, 0]
        for dy in -1...1 {
            for dx in -1...1 {
                let pixel = buffer.pixel(x: x + dx, y: y + dy)
                sums[0] += Int(pixel.r)
                sums[1] += Int(pixel.g)
                sums[2] += Int(pixel.b)
                sums[3] += Int(pixel.a)
            }
        }
        guard sums[3] > 0 else { return nil }
        return RGBA(
            r: UInt8(min(255, (sums[0] * 255 + sums[3] / 2) / sums[3])),
            g: UInt8(min(255, (sums[1] * 255 + sums[3] / 2) / sums[3])),
            b: UInt8(min(255, (sums[2] * 255 + sums[3] / 2) / sums[3])),
            a: 255
        )
    }

    static func mask(in buffer: PixelBuffer, include: [RGBA], exclude: [RGBA], fuzziness: Int, invert: Bool) -> [UInt8] {
        let width = buffer.width
        let height = buffer.height
        let bytes = buffer.copyBytes()
        let limit = min(255, max(0, fuzziness))
        var selected = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let alpha = Int(bytes[index + 3])
                var matches = false
                if alpha > 0 {
                    let rgb = (0..<3).map { channel in
                        (Int(bytes[index + channel]) * 255 + alpha / 2) / alpha
                    }
                    matches = near(rgb, colors: include, fuzziness: limit) && !near(rgb, colors: exclude, fuzziness: limit)
                }
                if invert { matches.toggle() }
                selected[y * width + x] = matches ? 255 : 0
            }
        }
        return selected
    }

    private static func near(_ rgb: [Int], colors: [RGBA], fuzziness: Int) -> Bool {
        for color in colors {
            let channels = [Int(color.r), Int(color.g), Int(color.b)]
            let close = zip(rgb, channels).allSatisfy { abs($0 - $1) <= fuzziness }
            if close { return true }
        }
        return false
    }
}
