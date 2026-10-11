// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

/// Grayscale coverage stored as a straight RGB image. White reveals, black hides.
struct LayerMask: Equatable, Sendable {
    var buffer: PixelBuffer
    var isEnabled: Bool

    static func filled(width: Int, height: Int, revealing: Bool) -> LayerMask {
        LayerMask(
            buffer: PixelBuffer(width: width, height: height, fill: revealing ? .white : .black),
            isEnabled: true
        )
    }

    func coverage(x: Int, y: Int) -> UInt8 {
        guard isEnabled else { return 255 }
        guard x >= 0, y >= 0, x < buffer.width, y < buffer.height else { return 0 }
        return buffer.pixel(x: x, y: y).r
    }

    func inverted() -> LayerMask {
        var copy = self
        copy.buffer.updateEach { _, _, pixel in
            let value = 255 - pixel.r
            pixel = RGBA(r: value, g: value, b: value, a: 255)
        }
        return copy
    }

    func applying(to buffer: PixelBuffer) -> PixelBuffer {
        guard isEnabled else { return buffer }
        var result = buffer
        result.updateEach { x, y, pixel in
            let coverage = Int(self.coverage(x: x, y: y))
            if coverage >= 255 { return }
            if coverage <= 0 {
                pixel = .clear
                return
            }
            pixel.a = UInt8((Int(pixel.a) * coverage + 127) / 255)
        }
        return result
    }
}
