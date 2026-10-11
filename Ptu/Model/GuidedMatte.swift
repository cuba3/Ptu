// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

/// Guided filter (He, Sun, and Tang). Pulls a mask onto the edges of a guide image.
enum GuidedMatte {
    static func box(_ source: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        let count = width * height
        guard width > 0, height > 0, source.count == count, radius >= 0 else { return source }
        let span = Float(radius * 2 + 1)
        var pass = [Float](repeating: 0, count: count)
        for y in 0..<height {
            let row = y * width
            var sum: Float = 0
            for x in -radius...radius { sum += source[row + min(width - 1, max(0, x))] }
            for x in 0..<width {
                pass[row + x] = sum / span
                sum -= source[row + min(width - 1, max(0, x - radius))]
                sum += source[row + min(width - 1, max(0, x + radius + 1))]
            }
        }
        var result = [Float](repeating: 0, count: count)
        for x in 0..<width {
            var sum: Float = 0
            for y in -radius...radius { sum += pass[min(height - 1, max(0, y)) * width + x] }
            for y in 0..<height {
                result[y * width + x] = sum / span
                sum -= pass[min(height - 1, max(0, y - radius)) * width + x]
                sum += pass[min(height - 1, max(0, y + radius + 1)) * width + x]
            }
        }
        return result
    }

    static func filter(mask: [Float], guide: [Float], width: Int, height: Int, radius: Int, epsilon: Float) -> [Float] {
        let count = width * height
        guard mask.count == count, guide.count == count, width > 0, height > 0 else { return mask }
        let meanGuide = box(guide, width: width, height: height, radius: radius)
        let meanMask = box(mask, width: width, height: height, radius: radius)
        var squares = [Float](repeating: 0, count: count)
        var products = [Float](repeating: 0, count: count)
        for index in 0..<count {
            squares[index] = guide[index] * guide[index]
            products[index] = guide[index] * mask[index]
        }
        let meanSquares = box(squares, width: width, height: height, radius: radius)
        let meanProducts = box(products, width: width, height: height, radius: radius)
        var slope = [Float](repeating: 0, count: count)
        var offset = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let variance = meanSquares[index] - meanGuide[index] * meanGuide[index]
            let covariance = meanProducts[index] - meanGuide[index] * meanMask[index]
            slope[index] = covariance / (variance + epsilon)
            offset[index] = meanMask[index] - slope[index] * meanGuide[index]
        }
        let meanSlope = box(slope, width: width, height: height, radius: radius)
        let meanOffset = box(offset, width: width, height: height, radius: radius)
        var result = [Float](repeating: 0, count: count)
        for index in 0..<count {
            result[index] = min(1, max(0, meanSlope[index] * guide[index] + meanOffset[index]))
        }
        return result
    }
}
