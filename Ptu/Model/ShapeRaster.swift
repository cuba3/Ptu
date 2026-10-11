// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum ShapeKind: String, CaseIterable, Identifiable, Sendable {
    case rectangle
    case ellipse
    case line

    var id: String { rawValue }
}

struct PlacedRaster: Equatable, Sendable {
    var buffer: PixelBuffer
    var originX: Int
    var originY: Int
}

enum ShapeRaster {
    static func rectangle(_ rect: CGRect, color: RGBA, cornerRadius: CGFloat) -> PlacedRaster? {
        let area = rect.standardized
        let width = Int(area.width.rounded(.down))
        let height = Int(area.height.rounded(.down))
        guard width >= 1, height >= 1 else { return nil }
        var buffer = PixelBuffer(width: width, height: height, fill: .clear)
        let radius = min(max(0, cornerRadius), CGFloat(width) / 2, CGFloat(height) / 2)
        buffer.updateEach { x, y, pixel in
            if insideRoundedRect(x: x, y: y, width: width, height: height, radius: radius) {
                pixel = color.opaque
            }
        }
        return PlacedRaster(buffer: buffer, originX: Int(area.minX.rounded(.down)), originY: Int(area.minY.rounded(.down)))
    }

    static func ellipse(_ rect: CGRect, color: RGBA) -> PlacedRaster? {
        let area = rect.standardized
        let width = Int(area.width.rounded(.down))
        let height = Int(area.height.rounded(.down))
        guard width >= 1, height >= 1 else { return nil }
        var buffer = PixelBuffer(width: width, height: height, fill: .clear)
        let rx = CGFloat(width) / 2
        let ry = CGFloat(height) / 2
        buffer.updateEach { x, y, pixel in
            var inside = 0
            for sample in [0.25, 0.75] {
                for other in [0.25, 0.75] {
                    let nx = (CGFloat(x) + sample - rx) / rx
                    let ny = (CGFloat(y) + other - ry) / ry
                    if nx * nx + ny * ny <= 1 { inside += 1 }
                }
            }
            guard inside > 0 else { return }
            var painted = color.opaque
            painted.a = UInt8(inside * 255 / 4)
            pixel = painted
        }
        return PlacedRaster(buffer: buffer, originX: Int(area.minX.rounded(.down)), originY: Int(area.minY.rounded(.down)))
    }

    static func line(from start: CGPoint, to end: CGPoint, thickness: CGFloat, color: RGBA) -> PlacedRaster? {
        let width = max(1, thickness)
        let minX = min(start.x, end.x) - width / 2
        let minY = min(start.y, end.y) - width / 2
        let maxX = max(start.x, end.x) + width / 2
        let maxY = max(start.y, end.y) + width / 2
        let originX = Int(floor(minX))
        let originY = Int(floor(minY))
        let pixelWidth = max(1, Int(ceil(maxX)) - originX)
        let pixelHeight = max(1, Int(ceil(maxY)) - originY)
        guard pixelWidth * pixelHeight <= 16_000 * 16_000 else { return nil }
        var buffer = PixelBuffer(width: pixelWidth, height: pixelHeight, fill: .clear)
        let localStart = CGPoint(x: start.x - CGFloat(originX), y: start.y - CGFloat(originY))
        let localEnd = CGPoint(x: end.x - CGFloat(originX), y: end.y - CGFloat(originY))
        buffer.updateEach { x, y, pixel in
            let distance = distanceToSegment(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5), localStart, localEnd)
            let edge = width / 2
            guard distance <= edge + 0.5 else { return }
            let coverage = distance <= edge ? 1 : max(0, 1 - (distance - edge))
            var painted = color.opaque
            painted.a = UInt8(clamping: Int((coverage * 255).rounded()))
            pixel = painted
        }
        return PlacedRaster(buffer: buffer, originX: originX, originY: originY)
    }

    private static func insideRoundedRect(x: Int, y: Int, width: Int, height: Int, radius: CGFloat) -> Bool {
        let px = CGFloat(x) + 0.5
        let py = CGFloat(y) + 0.5
        guard radius > 0 else { return true }
        let left = radius
        let right = CGFloat(width) - radius
        let top = radius
        let bottom = CGFloat(height) - radius
        let cx: CGFloat
        let cy: CGFloat
        if px < left && py < top {
            cx = left
            cy = top
        } else if px > right && py < top {
            cx = right
            cy = top
        } else if px < left && py > bottom {
            cx = left
            cy = bottom
        } else if px > right && py > bottom {
            cx = right
            cy = bottom
        } else {
            return true
        }
        return hypot(px - cx, py - cy) <= radius
    }

    private static func distanceToSegment(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length2 = dx * dx + dy * dy
        guard length2 > 0 else { return hypot(point.x - start.x, point.y - start.y) }
        let t = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / length2))
        return hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy))
    }
}
