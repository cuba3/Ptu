// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

extension PixelBuffer {
    func flippedHorizontally() -> PixelBuffer {
        let source = copyBytes()
        var destination = [UInt8](repeating: 0, count: source.count)
        for y in 0..<height {
            for x in 0..<width {
                let from = (y * width + x) * 4
                let to = (y * width + (width - 1 - x)) * 4
                destination[to] = source[from]
                destination[to + 1] = source[from + 1]
                destination[to + 2] = source[from + 2]
                destination[to + 3] = source[from + 3]
            }
        }
        return PixelBuffer(bytes: destination, width: width, height: height)
    }

    func flippedVertically() -> PixelBuffer {
        let source = copyBytes()
        var destination = [UInt8](repeating: 0, count: source.count)
        let rowBytes = width * 4
        for y in 0..<height {
            let from = y * rowBytes
            let to = (height - 1 - y) * rowBytes
            destination.replaceSubrange(to..<(to + rowBytes), with: source[from..<(from + rowBytes)])
        }
        return PixelBuffer(bytes: destination, width: width, height: height)
    }

    /// Top-left pixel moves to the top-right. New size is height × width.
    func rotatedClockwise() -> PixelBuffer {
        let source = copyBytes()
        let newWidth = height
        let newHeight = width
        var destination = [UInt8](repeating: 0, count: newWidth * newHeight * 4)
        for y in 0..<height {
            for x in 0..<width {
                let from = (y * width + x) * 4
                let nx = height - 1 - y
                let ny = x
                let to = (ny * newWidth + nx) * 4
                destination[to] = source[from]
                destination[to + 1] = source[from + 1]
                destination[to + 2] = source[from + 2]
                destination[to + 3] = source[from + 3]
            }
        }
        return PixelBuffer(bytes: destination, width: newWidth, height: newHeight)
    }

    /// Top-left pixel moves to the bottom-left. New size is height × width.
    func rotatedCounterclockwise() -> PixelBuffer {
        let source = copyBytes()
        let newWidth = height
        let newHeight = width
        var destination = [UInt8](repeating: 0, count: newWidth * newHeight * 4)
        for y in 0..<height {
            for x in 0..<width {
                let from = (y * width + x) * 4
                let nx = y
                let ny = width - 1 - x
                let to = (ny * newWidth + nx) * 4
                destination[to] = source[from]
                destination[to + 1] = source[from + 1]
                destination[to + 2] = source[from + 2]
                destination[to + 3] = source[from + 3]
            }
        }
        return PixelBuffer(bytes: destination, width: newWidth, height: newHeight)
    }

    func rotated180() -> PixelBuffer {
        let source = copyBytes()
        var destination = [UInt8](repeating: 0, count: source.count)
        for y in 0..<height {
            for x in 0..<width {
                let from = (y * width + x) * 4
                let to = ((height - 1 - y) * width + (width - 1 - x)) * 4
                destination[to] = source[from]
                destination[to + 1] = source[from + 1]
                destination[to + 2] = source[from + 2]
                destination[to + 3] = source[from + 3]
            }
        }
        return PixelBuffer(bytes: destination, width: width, height: height)
    }

    func resampled(toWidth newWidth: Int, height newHeight: Int, sampling: LayerSampling) -> PixelBuffer {
        guard newWidth >= 1, newHeight >= 1 else { return self }
        if newWidth == width, newHeight == height { return self }
        if sampling == .nearest {
            return nearestScaled(toWidth: newWidth, height: newHeight)
        }
        guard let image = cgImage(), let context = Compositor.makeContext(width: newWidth, height: newHeight) else {
            return nearestScaled(toWidth: newWidth, height: newHeight)
        }
        context.interpolationQuality = sampling.quality
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        guard let rendered = context.makeImage(), let buffer = PixelBuffer.from(cgImage: rendered) else {
            return nearestScaled(toWidth: newWidth, height: newHeight)
        }
        return buffer
    }

    private func nearestScaled(toWidth newWidth: Int, height newHeight: Int) -> PixelBuffer {
        var bytes = [UInt8](repeating: 0, count: newWidth * newHeight * 4)
        let source = copyBytes()
        for y in 0..<newHeight {
            for x in 0..<newWidth {
                let sx = min(width - 1, Int(floor((CGFloat(x) + 0.5) * CGFloat(width) / CGFloat(newWidth))))
                let sy = min(height - 1, Int(floor((CGFloat(y) + 0.5) * CGFloat(height) / CGFloat(newHeight))))
                let from = (sy * width + sx) * 4
                let to = (y * newWidth + x) * 4
                bytes[to] = source[from]
                bytes[to + 1] = source[from + 1]
                bytes[to + 2] = source[from + 2]
                bytes[to + 3] = source[from + 3]
            }
        }
        return PixelBuffer(bytes: bytes, width: newWidth, height: newHeight)
    }
}

enum PixelRasterizer {
    /// Bakes `placement` into an axis-aligned buffer. A plain move keeps the original pixels.
    static func bake(source: PixelBuffer, placement: LayerPlacement) -> (buffer: PixelBuffer, originX: Int, originY: Int)? {
        guard placement.isValid else { return nil }
        let turns = placement.rotation.truncatingRemainder(dividingBy: 360)
        let upright = abs(turns) < 0.001 || abs(abs(turns) - 360) < 0.001
        let sameSize = abs(placement.size.width - CGFloat(source.width)) < 0.001
            && abs(placement.size.height - CGFloat(source.height)) < 0.001
        if upright && sameSize {
            var buffer = source
            if placement.flipX { buffer = buffer.flippedHorizontally() }
            if placement.flipY { buffer = buffer.flippedVertically() }
            return (buffer, Int(placement.origin.x.rounded()), Int(placement.origin.y.rounded()))
        }
        let corners = placement.corners()
        guard let bounds = integerBounds(corners) else { return nil }
        return sample(source: source, width: bounds.width, height: bounds.height, originX: bounds.minX, originY: bounds.minY) { x, y in
            let documentPoint = CGPoint(x: CGFloat(bounds.minX) + CGFloat(x) + 0.5, y: CGFloat(bounds.minY) + CGFloat(y) + 0.5)
            guard placement.contains(documentPoint) else { return .clear }
            let dx = documentPoint.x - placement.center.x
            let dy = documentPoint.y - placement.center.y
            let cosine = cos(placement.radians)
            let sine = sin(placement.radians)
            var localX = dx * cosine + dy * sine
            var localY = -dx * sine + dy * cosine
            if placement.flipX { localX = -localX }
            if placement.flipY { localY = -localY }
            let unitX = localX / placement.size.width + 0.5
            let unitY = localY / placement.size.height + 0.5
            return source.sample(unitX: unitX, unitY: unitY, sampling: placement.sampling)
        }
    }

    private static func integerBounds(_ corners: [CGPoint]) -> (minX: Int, minY: Int, width: Int, height: Int)? {
        guard let minCornerX = corners.map(\.x).min(), let minCornerY = corners.map(\.y).min(),
              let maxCornerX = corners.map(\.x).max(), let maxCornerY = corners.map(\.y).max() else { return nil }
        let minX = Int(floor(minCornerX))
        let minY = Int(floor(minCornerY))
        let maxX = Int(ceil(maxCornerX))
        let maxY = Int(ceil(maxCornerY))
        let width = max(1, maxX - minX)
        let height = max(1, maxY - minY)
        guard width <= DocumentModel.maximumSide, height <= DocumentModel.maximumSide else { return nil }
        return (minX, minY, width, height)
    }

    private static func sample(
        source: PixelBuffer,
        width: Int,
        height: Int,
        originX: Int,
        originY: Int,
        pixel: (Int, Int) -> RGBA
    ) -> (buffer: PixelBuffer, originX: Int, originY: Int)? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let color = pixel(x, y)
                let index = (y * width + x) * 4
                bytes[index] = color.r
                bytes[index + 1] = color.g
                bytes[index + 2] = color.b
                bytes[index + 3] = color.a
            }
        }
        return (PixelBuffer(bytes: bytes, width: width, height: height), originX, originY)
    }
}

extension PixelBuffer {
    func sample(unitX: CGFloat, unitY: CGFloat, sampling: LayerSampling) -> RGBA {
        guard unitX.isFinite, unitY.isFinite else { return .clear }
        let x = unitX * CGFloat(width) - 0.5
        let y = unitY * CGFloat(height) - 0.5
        if sampling == .nearest {
            return pixel(x: Int(x.rounded()), y: Int(y.rounded()))
        }
        return bilinear(x, y)
    }

    private func bilinear(_ x: CGFloat, _ y: CGFloat) -> RGBA {
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = x0 + 1
        let y1 = y0 + 1
        let tx = x - CGFloat(x0)
        let ty = y - CGFloat(y0)
        let c00 = pixel(x: x0, y: y0)
        let c10 = pixel(x: x1, y: y0)
        let c01 = pixel(x: x0, y: y1)
        let c11 = pixel(x: x1, y: y1)
        func channel(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> UInt8 {
            let top = CGFloat(a) * (1 - tx) + CGFloat(b) * tx
            let bottom = CGFloat(c) * (1 - tx) + CGFloat(d) * tx
            return UInt8(clamping: Int((top * (1 - ty) + bottom * ty).rounded()))
        }
        return RGBA(
            r: channel(c00.r, c10.r, c01.r, c11.r),
            g: channel(c00.g, c10.g, c01.g, c11.g),
            b: channel(c00.b, c10.b, c01.b, c11.b),
            a: channel(c00.a, c10.a, c01.a, c11.a)
        )
    }
}

enum PixelWarp {
    static func isConvex(_ corners: [CGPoint]) -> Bool {
        guard corners.count == 4 else { return false }
        var sign: CGFloat = 0
        for index in 0..<4 {
            let a = corners[index]
            let b = corners[(index + 1) % 4]
            let c = corners[(index + 2) % 4]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            if abs(cross) <= 0.01 { return false }
            if sign == 0 {
                sign = cross < 0 ? -1 : 1
            } else if (cross < 0) != (sign < 0) {
                return false
            }
        }
        return true
    }

    /// Maps the unit square onto `corners` (top-left, top-right, bottom-right, bottom-left).
    static func project(unit: CGPoint, corners: [CGPoint]) -> CGPoint? {
        guard corners.count == 4, let forward = homography(corners) else { return nil }
        return forward(unit)
    }

    static func warp(source: PixelBuffer, corners: [CGPoint], sampling: LayerSampling) -> (buffer: PixelBuffer, originX: Int, originY: Int)? {
        guard corners.count == 4, corners.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        guard let minX = corners.map(\.x).min(), let minY = corners.map(\.y).min(),
              let maxX = corners.map(\.x).max(), let maxY = corners.map(\.y).max() else { return nil }
        let originX = Int(floor(minX))
        let originY = Int(floor(minY))
        let width = Int(ceil(maxX)) - originX
        let height = Int(ceil(maxY)) - originY
        guard width >= 1, height >= 1, width <= DocumentModel.maximumSide, height <= DocumentModel.maximumSide else { return nil }
        let convex = isConvex(corners)
        let inverse = homography(corners).flatMap(invert)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let documentPoint = CGPoint(x: CGFloat(originX) + CGFloat(x) + 0.5, y: CGFloat(originY) + CGFloat(y) + 0.5)
                let unit: CGPoint?
                if convex, let inverse {
                    unit = inverse(documentPoint)
                } else {
                    unit = triangleUnit(documentPoint, corners: corners)
                }
                guard let unit, unit.x >= -0.001, unit.y >= -0.001, unit.x <= 1.001, unit.y <= 1.001 else { continue }
                let color = source.sample(unitX: min(max(unit.x, 0), 1), unitY: min(max(unit.y, 0), 1), sampling: sampling)
                let index = (y * width + x) * 4
                bytes[index] = color.r
                bytes[index + 1] = color.g
                bytes[index + 2] = color.b
                bytes[index + 3] = color.a
            }
        }
        return (PixelBuffer(bytes: bytes, width: width, height: height), originX, originY)
    }

    private static func triangleUnit(_ point: CGPoint, corners: [CGPoint]) -> CGPoint? {
        let triangles = [
            (corners[0], corners[1], corners[2], CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1)),
            (corners[0], corners[2], corners[3], CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)),
        ]
        for (a, b, c, ua, ub, uc) in triangles {
            if let unit = barycentric(point, a, b, c, ua, ub, uc) { return unit }
        }
        return nil
    }

    private static func barycentric(
        _ point: CGPoint,
        _ a: CGPoint, _ b: CGPoint, _ c: CGPoint,
        _ ua: CGPoint, _ ub: CGPoint, _ uc: CGPoint
    ) -> CGPoint? {
        let denominator = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
        guard abs(denominator) > 1e-8 else { return nil }
        let alpha = ((b.y - c.y) * (point.x - c.x) + (c.x - b.x) * (point.y - c.y)) / denominator
        let beta = ((c.y - a.y) * (point.x - c.x) + (a.x - c.x) * (point.y - c.y)) / denominator
        let gamma = 1 - alpha - beta
        guard alpha >= -0.001, beta >= -0.001, gamma >= -0.001 else { return nil }
        return CGPoint(
            x: alpha * ua.x + beta * ub.x + gamma * uc.x,
            y: alpha * ua.y + beta * ub.y + gamma * uc.y
        )
    }

    private static func homography(_ corners: [CGPoint]) -> ((CGPoint) -> CGPoint)? {
        let c = corners
        let sx = c[0].x - c[1].x + c[2].x - c[3].x
        let sy = c[0].y - c[1].y + c[2].y - c[3].y
        var g: CGFloat = 0
        var h: CGFloat = 0
        if abs(sx) > 1e-9 || abs(sy) > 1e-9 {
            let dx1 = c[1].x - c[2].x
            let dx2 = c[3].x - c[2].x
            let dy1 = c[1].y - c[2].y
            let dy2 = c[3].y - c[2].y
            let denominator = dx1 * dy2 - dx2 * dy1
            guard abs(denominator) > 1e-12 else { return nil }
            g = (sx * dy2 - dx2 * sy) / denominator
            h = (dx1 * sy - sx * dy1) / denominator
        }
        let a = c[1].x - c[0].x + g * c[1].x
        let b = c[3].x - c[0].x + h * c[3].x
        let x0 = c[0].x
        let d = c[1].y - c[0].y + g * c[1].y
        let e = c[3].y - c[0].y + h * c[3].y
        let y0 = c[0].y
        return { point in
            let weight = g * point.x + h * point.y + 1
            guard abs(weight) > 1e-8 else { return point }
            return CGPoint(x: (a * point.x + b * point.y + x0) / weight, y: (d * point.x + e * point.y + y0) / weight)
        }
    }

    private static func invert(_ forward: @escaping (CGPoint) -> CGPoint) -> ((CGPoint) -> CGPoint)? {
        let origin = forward(.zero)
        let right = forward(CGPoint(x: 1, y: 0))
        let down = forward(CGPoint(x: 0, y: 1))
        let far = forward(CGPoint(x: 1, y: 1))
        let sx = origin.x - right.x + far.x - down.x
        let sy = origin.y - right.y + far.y - down.y
        var g: CGFloat = 0
        var h: CGFloat = 0
        if abs(sx) > 1e-9 || abs(sy) > 1e-9 {
            let dx1 = right.x - far.x
            let dx2 = down.x - far.x
            let dy1 = right.y - far.y
            let dy2 = down.y - far.y
            let denominator = dx1 * dy2 - dx2 * dy1
            guard abs(denominator) > 1e-12 else { return nil }
            g = (sx * dy2 - dx2 * sy) / denominator
            h = (dx1 * sy - sx * dy1) / denominator
        }
        let a = right.x - origin.x + g * right.x
        let b = down.x - origin.x + h * down.x
        let x0 = origin.x
        let d = right.y - origin.y + g * right.y
        let e = down.y - origin.y + h * down.y
        let y0 = origin.y
        let matrix = (a, b, x0, d, e, y0, g, h, CGFloat(1))
        guard let inverse = invert3(matrix) else { return nil }
        return { point in
            let x = inverse.0 * point.x + inverse.1 * point.y + inverse.2
            let y = inverse.3 * point.x + inverse.4 * point.y + inverse.5
            let weight = inverse.6 * point.x + inverse.7 * point.y + inverse.8
            guard abs(weight) > 1e-8 else { return .zero }
            return CGPoint(x: x / weight, y: y / weight)
        }
    }

    private static func invert3(
        _ m: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)? {
        let (a, b, c, d, e, f, g, h, i) = m
        let a00 = e * i - f * h
        let a01 = c * h - b * i
        let a02 = b * f - c * e
        let a10 = f * g - d * i
        let a11 = a * i - c * g
        let a12 = c * d - a * f
        let a20 = d * h - e * g
        let a21 = b * g - a * h
        let a22 = a * e - b * d
        let determinant = a * a00 + b * a10 + c * a20
        guard abs(determinant) > 1e-12 else { return nil }
        let scale = 1 / determinant
        return (a00 * scale, a01 * scale, a02 * scale, a10 * scale, a11 * scale, a12 * scale, a20 * scale, a21 * scale, a22 * scale)
    }
}

enum TrimBasedOn: String, CaseIterable, Sendable, Identifiable {
    case transparent
    case topLeft
    case bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transparent: L10n.Trim.transparent
        case .topLeft: L10n.Trim.topLeft
        case .bottomRight: L10n.Trim.bottomRight
        }
    }
}

struct TrimOptions: Equatable, Sendable {
    var basedOn: TrimBasedOn = .transparent
    var top = true
    var bottom = true
    var left = true
    var right = true
    var tolerance: UInt8 = 0

    var trimsAny: Bool { top || bottom || left || right }
}

enum ImageTrim {
    static func bounds(in buffer: PixelBuffer, options: TrimOptions) -> CGRect? {
        guard options.trimsAny, buffer.width > 0, buffer.height > 0 else { return nil }
        let content: (minX: Int, minY: Int, maxX: Int, maxY: Int)?
        switch options.basedOn {
        case .transparent:
            content = span(buffer) { $0.a > options.tolerance }
        case .topLeft:
            let sample = buffer.pixel(x: 0, y: 0)
            content = span(buffer) { !matches($0, sample, tolerance: options.tolerance) }
        case .bottomRight:
            let sample = buffer.pixel(x: buffer.width - 1, y: buffer.height - 1)
            content = span(buffer) { !matches($0, sample, tolerance: options.tolerance) }
        }
        guard let content else { return nil }
        let minX = options.left ? content.minX : 0
        let minY = options.top ? content.minY : 0
        let maxX = options.right ? content.maxX : buffer.width
        let maxY = options.bottom ? content.maxY : buffer.height
        guard maxX > minX, maxY > minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func matches(_ pixel: RGBA, _ sample: RGBA, tolerance: UInt8) -> Bool {
        abs(Int(pixel.r) - Int(sample.r)) <= Int(tolerance)
            && abs(Int(pixel.g) - Int(sample.g)) <= Int(tolerance)
            && abs(Int(pixel.b) - Int(sample.b)) <= Int(tolerance)
            && abs(Int(pixel.a) - Int(sample.a)) <= Int(tolerance)
    }

    private static func span(_ buffer: PixelBuffer, isContent: (RGBA) -> Bool) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = buffer.width
        var minY = buffer.height
        var maxX = 0
        var maxY = 0
        for y in 0..<buffer.height {
            for x in 0..<buffer.width where isContent(buffer.pixel(x: x, y: y)) {
                if x < minX { minX = x }
                if y < minY { minY = y }
                if x + 1 > maxX { maxX = x + 1 }
                if y + 1 > maxY { maxY = y + 1 }
            }
        }
        guard maxX > minX, maxY > minY else { return nil }
        return (minX, minY, maxX, maxY)
    }
}
