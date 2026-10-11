// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

struct CurvePoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
}

struct CurvesSettings: Codable, Equatable, Sendable {
    var channel = LevelsChannel.rgb
    var channels = Array(repeating: [CurvePoint(x: 0, y: 0), CurvePoint(x: 255, y: 255)], count: 4)

    var isValid: Bool {
        channels.count == 4 && channels.allSatisfy { points in
            (2...32).contains(points.count)
                && points.first?.x == 0
                && points.last?.x == 255
                && points.allSatisfy { $0.x.isFinite && $0.y.isFinite && (0...255).contains($0.x) && (0...255).contains($0.y) }
                && zip(points, points.dropFirst()).allSatisfy { $0.x < $1.x }
        }
    }

    var isIdentity: Bool {
        channels.allSatisfy { points in
            points.count == 2 && points[0] == CurvePoint(x: 0, y: 0) && points[1] == CurvePoint(x: 255, y: 255)
        }
    }

    /// Shape-preserving cubic Hermite interpolation avoids overshoot between handles.
    func value(_ x: Double, channel: Int) -> Double {
        let points = channels[channel]
        guard points.count >= 2 else { return x }
        let index = min(points.count - 2, max(0, points.lastIndex(where: { $0.x <= x }) ?? 0))
        let slopes = zip(points, points.dropFirst()).map { ($1.y - $0.y) / ($1.x - $0.x) }
        func slope(_ j: Int) -> Double {
            if j == 0 { return slopes[0] }
            if j == points.count - 1 { return slopes[slopes.count - 1] }
            if slopes[j - 1] * slopes[j] <= 0 { return 0 }
            return 2 / (1 / slopes[j - 1] + 1 / slopes[j])
        }
        let span = points[index + 1].x - points[index].x
        let t = min(1, max(0, (x - points[index].x) / span))
        let y = (2 * t * t * t - 3 * t * t + 1) * points[index].y
            + (t * t * t - 2 * t * t + t) * span * slope(index)
            + (-2 * t * t * t + 3 * t * t) * points[index + 1].y
            + (t * t * t - t * t) * span * slope(index + 1)
        return min(255, max(0, y))
    }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        guard isValid, !isIdentity else { return buffer }
        let table = (1...3).map { channel in
            (0...255).map { input -> UInt8 in
                let perChannel = value(Double(input), channel: channel)
                return PixelMath.byte(value(perChannel, channel: 0) / 255)
            }
        }
        var result = buffer
        result.updateEach { _, _, pixel in
            guard pixel.a > 0 else { return }
            pixel.r = table[0][Int(pixel.r)]
            pixel.g = table[1][Int(pixel.g)]
            pixel.b = table[2][Int(pixel.b)]
        }
        return result
    }
}
