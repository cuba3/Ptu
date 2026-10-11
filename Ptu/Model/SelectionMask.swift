// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum SelectionMode: Sendable {
    case replace
    case add
    case subtract
}

enum MarqueeShape: String, CaseIterable, Identifiable, Sendable {
    case rectangle
    case ellipse

    var id: String { rawValue }
}

enum LassoKind: String, CaseIterable, Identifiable, Sendable {
    case freehand
    case polygonal

    var id: String { rawValue }
}

enum SelectionElement: Equatable, Sendable {
    case rect(CGRect)
    case ellipse(CGRect)
    case polygon([CGPoint])
}

struct SelectionGeometry: Equatable, Sendable {
    var elements: [SelectionElement] = []

    var isEmpty: Bool {
        elements.allSatisfy { element in
            switch element {
            case .rect(let rect), .ellipse(let rect):
                rect.width < 1 || rect.height < 1
            case .polygon(let points):
                points.count < 3
            }
        }
    }

    var bounds: CGRect {
        elements.reduce(CGRect.null) { partial, element in
            let rect: CGRect
            switch element {
            case .rect(let value), .ellipse(let value):
                rect = value
            case .polygon(let points):
                guard let first = points.first else { return partial }
                rect = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
            }
            return partial.isNull ? rect : partial.union(rect)
        }
    }

    func contains(_ point: CGPoint) -> Bool {
        elements.contains { element in
            switch element {
            case .rect(let rect):
                rect.contains(point)
            case .ellipse(let rect):
                Self.ellipseContains(point, rect)
            case .polygon(let points):
                Self.polygonContains(point, points)
            }
        }
    }

    func rasterize(width: Int, height: Int) -> [UInt8] {
        var mask = [UInt8](repeating: 0, count: max(0, width * height))
        guard width > 0, height > 0 else { return mask }
        for element in elements {
            switch element {
            case .rect(let rect):
                Self.fillRect(rect, into: &mask, width: width, height: height)
            case .ellipse(let rect):
                Self.fillEllipse(rect, into: &mask, width: width, height: height)
            case .polygon(let points):
                Self.fillPolygon(points, into: &mask, width: width, height: height)
            }
        }
        return mask
    }

    func offset(dx: Int, dy: Int) -> SelectionGeometry {
        let shift = CGSize(width: dx, height: dy)
        return SelectionGeometry(elements: elements.map { element in
            switch element {
            case .rect(let rect):
                .rect(rect.offsetBy(dx: shift.width, dy: shift.height))
            case .ellipse(let rect):
                .ellipse(rect.offsetBy(dx: shift.width, dy: shift.height))
            case .polygon(let points):
                .polygon(points.map { CGPoint(x: $0.x + shift.width, y: $0.y + shift.height) })
            }
        })
    }

    private static func ellipseContains(_ point: CGPoint, _ rect: CGRect) -> Bool {
        guard rect.width > 0, rect.height > 0 else { return false }
        let nx = (point.x - rect.midX) / (rect.width / 2)
        let ny = (point.y - rect.midY) / (rect.height / 2)
        return nx * nx + ny * ny <= 1
    }

    private static func polygonContains(_ point: CGPoint, _ points: [CGPoint]) -> Bool {
        guard points.count >= 3 else { return false }
        var inside = false
        var previous = points.count - 1
        for index in points.indices {
            let current = points[index]
            let other = points[previous]
            if (current.y > point.y) != (other.y > point.y) {
                let x = (other.x - current.x) * (point.y - current.y) / (other.y - current.y) + current.x
                if point.x < x { inside.toggle() }
            }
            previous = index
        }
        return inside
    }

    private static func fillRect(_ rect: CGRect, into mask: inout [UInt8], width: Int, height: Int) {
        let area = rect.standardized.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard area.width >= 1, area.height >= 1 else { return }
        let minX = max(0, Int(area.minX.rounded(.down)))
        let minY = max(0, Int(area.minY.rounded(.down)))
        let maxX = min(width, Int(area.maxX.rounded(.up)))
        let maxY = min(height, Int(area.maxY.rounded(.up)))
        guard minX < maxX, minY < maxY else { return }
        for y in minY..<maxY {
            for x in minX..<maxX {
                mask[y * width + x] = 255
            }
        }
    }

    private static func fillEllipse(_ rect: CGRect, into mask: inout [UInt8], width: Int, height: Int) {
        guard rect.width >= 1, rect.height >= 1 else { return }
        let minX = max(0, Int(floor(rect.minX)))
        let minY = max(0, Int(floor(rect.minY)))
        let maxX = min(width - 1, Int(ceil(rect.maxX)))
        let maxY = min(height - 1, Int(ceil(rect.maxY)))
        let rx = rect.width / 2
        let ry = rect.height / 2
        guard rx > 0, ry > 0, minX <= maxX, minY <= maxY else { return }
        let samples: [CGPoint] = [
            CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.75, y: 0.25),
            CGPoint(x: 0.25, y: 0.75), CGPoint(x: 0.75, y: 0.75)
        ]
        for y in minY...maxY {
            for x in minX...maxX {
                var inside = 0
                for sample in samples {
                    let nx = (CGFloat(x) + sample.x - rect.midX) / rx
                    let ny = (CGFloat(y) + sample.y - rect.midY) / ry
                    if nx * nx + ny * ny <= 1 { inside += 1 }
                }
                if inside > 0 {
                    mask[y * width + x] = UInt8(inside * 255 / samples.count)
                }
            }
        }
    }

    private static func fillPolygon(_ points: [CGPoint], into mask: inout [UInt8], width: Int, height: Int) {
        guard points.count >= 3 else { return }
        var ring = points
        if ring.first != ring.last { ring.append(ring[0]) }
        let minY = max(0, Int(floor(ring.map(\.y).min() ?? 0)))
        let maxY = min(height - 1, Int(ceil(ring.map(\.y).max() ?? 0)))
        guard minY <= maxY else { return }
        for y in minY...maxY {
            let scan = CGFloat(y) + 0.5
            var crossings: [CGFloat] = []
            for index in 0..<(ring.count - 1) {
                let start = ring[index]
                let end = ring[index + 1]
                let crosses = (start.y <= scan && end.y > scan) || (end.y <= scan && start.y > scan)
                guard crosses, end.y != start.y else { continue }
                let t = (scan - start.y) / (end.y - start.y)
                crossings.append(start.x + t * (end.x - start.x))
            }
            crossings.sort()
            var index = 0
            while index + 1 < crossings.count {
                let x0 = max(0, Int(ceil(crossings[index])))
                let x1 = min(width, Int(floor(crossings[index + 1])))
                if x0 < x1 {
                    for x in x0..<x1 {
                        mask[y * width + x] = 255
                    }
                }
                index += 2
            }
        }
    }
}

/// Document-space selection. A rectangular marquee stays geometry until an edit needs coverage.
/// Raster tools (wand, color range, object selection, feather, boolean ops) store `mask`.
struct PixelSelection: Equatable, Sendable {
    var width: Int
    var height: Int
    var geometry: SelectionGeometry
    var feather: CGFloat
    var mask: [UInt8]?
    var isEmpty: Bool
    var bounds: CGRect

    var rectangularArea: CGRect? {
        guard mask == nil, feather <= 0, geometry.elements.count == 1,
              case .rect(let rect) = geometry.elements[0] else { return nil }
        return rect
    }

    func contains(_ point: CGPoint) -> Bool {
        if let mask {
            let x = Int(point.x.rounded(.down))
            let y = Int(point.y.rounded(.down))
            guard x >= 0, y >= 0, x < width, y < height else { return false }
            return mask[y * width + x] >= 128
        }
        return geometry.contains(point)
    }

    func hardCoverage() -> [UInt8] {
        if let mask { return mask }
        return geometry.rasterize(width: width, height: height)
    }

    func resolvedCoverage() -> [UInt8] {
        let hard = hardCoverage()
        guard feather > 0.5 else { return hard }
        return MaskBlur.gaussian(hard, width: width, height: height, sigma: feather / 2)
    }

    func combining(_ other: PixelSelection, mode: SelectionMode) -> PixelSelection? {
        switch mode {
        case .replace:
            return other.isEmpty ? nil : other
        case .add, .subtract:
            let left = hardCoverage()
            let right = other.hardCoverage()
            guard left.count == right.count else { return other }
            var combined = left
            if mode == .add {
                for index in combined.indices where right[index] > combined[index] {
                    combined[index] = right[index]
                }
            } else {
                for index in combined.indices where right[index] > 0 {
                    combined[index] = 0
                }
            }
            return Self.covering(combined, width: width, height: height)
        }
    }

    func feathered(by amount: CGFloat) -> PixelSelection {
        var copy = self
        let extra = max(0, amount)
        copy.feather = min(250, hypot(feather, extra))
        return copy
    }

    func inverted() -> PixelSelection? {
        var hard = hardCoverage()
        for index in hard.indices {
            hard[index] = 255 - hard[index]
        }
        return Self.covering(hard, width: width, height: height, feather: feather)
    }

    func offset(dx: Int, dy: Int) -> PixelSelection? {
        guard dx != 0 || dy != 0 else { return self }
        if let mask {
            return Self.covering(Self.shift(mask, width: width, height: height, dx: dx, dy: dy), width: width, height: height, feather: feather)
        }
        let moved = geometry.offset(dx: dx, dy: dy)
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        let bounds = moved.bounds.intersection(canvas)
        guard !moved.isEmpty, !bounds.isNull, bounds.width >= 1, bounds.height >= 1 else { return nil }
        return PixelSelection(width: width, height: height, geometry: moved, feather: feather, mask: nil, isEmpty: false, bounds: bounds)
    }

    static func rectangle(_ rect: CGRect, width: Int, height: Int) -> PixelSelection? {
        let area = rect.standardized.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard area.width >= 1, area.height >= 1 else { return nil }
        return PixelSelection(
            width: width,
            height: height,
            geometry: SelectionGeometry(elements: [.rect(area)]),
            feather: 0,
            mask: nil,
            isEmpty: false,
            bounds: area
        )
    }

    static func ellipse(_ rect: CGRect, width: Int, height: Int) -> PixelSelection? {
        let area = rect.standardized
        guard area.width >= 1, area.height >= 1 else { return nil }
        let bounds = area.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard bounds.width >= 1, bounds.height >= 1 else { return nil }
        return PixelSelection(
            width: width,
            height: height,
            geometry: SelectionGeometry(elements: [.ellipse(area)]),
            feather: 0,
            mask: nil,
            isEmpty: false,
            bounds: bounds
        )
    }

    static func polygon(_ points: [CGPoint], width: Int, height: Int) -> PixelSelection? {
        guard points.count >= 3 else { return nil }
        let geometry = SelectionGeometry(elements: [.polygon(points)])
        let bounds = geometry.bounds.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard bounds.width >= 1, bounds.height >= 1 else { return nil }
        return PixelSelection(
            width: width,
            height: height,
            geometry: geometry,
            feather: 0,
            mask: nil,
            isEmpty: false,
            bounds: bounds
        )
    }

    static func covering(_ coverage: [UInt8], width: Int, height: Int, feather: CGFloat = 0) -> PixelSelection? {
        guard coverage.count == width * height else { return nil }
        let bounds = boundsOf(coverage, width: width, height: height)
        guard bounds.width >= 1, bounds.height >= 1 else { return nil }
        return PixelSelection(
            width: width,
            height: height,
            geometry: SelectionGeometry(),
            feather: feather,
            mask: coverage,
            isEmpty: false,
            bounds: bounds
        )
    }

    static func all(width: Int, height: Int) -> PixelSelection? {
        rectangle(CGRect(x: 0, y: 0, width: width, height: height), width: width, height: height)
    }

    static func boundsOf(_ mask: [UInt8], width: Int, height: Int) -> CGRect {
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var any = false
        guard mask.count == width * height else { return .zero }
        for y in 0..<height {
            for x in 0..<width where mask[y * width + x] > 0 {
                any = true
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x + 1)
                maxY = max(maxY, y + 1)
            }
        }
        guard any else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func shift(_ mask: [UInt8], width: Int, height: Int, dx: Int, dy: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            let sourceY = y - dy
            guard sourceY >= 0, sourceY < height else { continue }
            for x in 0..<width {
                let sourceX = x - dx
                guard sourceX >= 0, sourceX < width else { continue }
                out[y * width + x] = mask[sourceY * width + sourceX]
            }
        }
        return out
    }

    /// Accent-tinted preview. Row 0 is the top of the document.
    func tintImage() -> CGImage? {
        guard let mask, mask.count == width * height, width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for index in mask.indices {
            let alpha = mask[index]
            guard alpha > 0 else { continue }
            let offset = index * 4
            bytes[offset] = 10
            bytes[offset + 1] = 132
            bytes[offset + 2] = 255
            bytes[offset + 3] = alpha
        }
        let data = Data(bytes) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

enum MaskBlur {
    static func gaussian(_ source: [UInt8], width: Int, height: Int, sigma: CGFloat) -> [UInt8] {
        guard width > 0, height > 0, source.count == width * height, sigma > 0.05 else { return source }
        let radius = min(64, max(1, Int(ceil(sigma * 3))))
        var kernel = [Float](repeating: 0, count: radius * 2 + 1)
        let sigma2 = Float(sigma * sigma)
        var weightSum: Float = 0
        for offset in -radius...radius {
            let weight = exp(-0.5 * Float(offset * offset) / sigma2)
            kernel[offset + radius] = weight
            weightSum += weight
        }
        let inverse = 1 / weightSum
        for index in kernel.indices { kernel[index] *= inverse }

        var horizontal = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                for offset in -radius...radius {
                    let sample = min(width - 1, max(0, x + offset))
                    sum += Float(source[y * width + sample]) * kernel[offset + radius]
                }
                horizontal[y * width + x] = sum
            }
        }
        var vertical = [UInt8](repeating: 0, count: width * height)
        for x in 0..<width {
            for y in 0..<height {
                var sum: Float = 0
                for offset in -radius...radius {
                    let sample = min(height - 1, max(0, y + offset))
                    sum += horizontal[sample * width + x] * kernel[offset + radius]
                }
                vertical[y * width + x] = UInt8(clamping: Int(sum.rounded()))
            }
        }
        return vertical
    }
}

enum CanvasSample {
    static func layer(_ layer: PixelLayer, width: Int, height: Int) -> PixelBuffer {
        var canvas = PixelBuffer(width: max(1, width), height: max(1, height), fill: .clear)
        canvas.blit(layer.buffer, atX: layer.originX, y: layer.originY)
        return canvas
    }

    static func composite(_ model: DocumentModel) -> PixelBuffer? {
        guard let image = Compositor.render(model) else { return nil }
        return PixelBuffer.from(cgImage: image)
    }
}
