// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum BrushCoverage {
    static func weight(dx: CGFloat, dy: CGFloat, radius: CGFloat, hardness: CGFloat) -> CGFloat {
        let distance = hypot(dx, dy)
        guard distance <= radius else { return 0 }
        let inner = radius * min(max(hardness, 0), 1)
        if distance <= inner || inner >= radius { return 1 }
        let span = radius - inner
        guard span > 0 else { return 1 }
        return 1 - (distance - inner) / span
    }
}

enum CloneStamp {
    /// Copies pixels from `source` (document origin `sourceOrigin`) onto `destination`
    /// with a circular brush. `offset` is added to the brush center to find the source point.
    @discardableResult
    static func dab(
        destination: inout PixelBuffer,
        destinationOrigin: CGPoint,
        source: PixelBuffer,
        sourceOrigin: CGPoint,
        center: CGPoint,
        offset: CGSize,
        radius: CGFloat,
        hardness: CGFloat,
        opacity: CGFloat
    ) -> CGRect {
        let paintRadius = max(radius, 0.5)
        let minX = Int(floor(center.x - paintRadius))
        let maxX = Int(ceil(center.x + paintRadius))
        let minY = Int(floor(center.y - paintRadius))
        let maxY = Int(ceil(center.y + paintRadius))
        var dirty = CGRect.null
        let amountScale = min(max(opacity, 0), 1)
        guard amountScale > 0 else { return .null }
        for y in minY...maxY {
            for x in minX...maxX {
                let dx = CGFloat(x) + 0.5 - center.x
                let dy = CGFloat(y) + 0.5 - center.y
                let falloff = BrushCoverage.weight(dx: dx, dy: dy, radius: paintRadius, hardness: hardness)
                guard falloff > 0 else { continue }
                let sourceX = Int((CGFloat(x) + offset.width - sourceOrigin.x).rounded(.down))
                let sourceY = Int((CGFloat(y) + offset.height - sourceOrigin.y).rounded(.down))
                let sample = source.pixel(x: sourceX, y: sourceY)
                guard sample.a > 0 else { continue }
                let localX = x - Int(destinationOrigin.x.rounded(.down))
                let localY = y - Int(destinationOrigin.y.rounded(.down))
                destination.mixPixel(x: localX, y: localY, color: sample, amount: amountScale * falloff)
                let pixel = CGRect(x: x, y: y, width: 1, height: 1)
                dirty = dirty.isNull ? pixel : dirty.union(pixel)
            }
        }
        return dirty
    }
}
