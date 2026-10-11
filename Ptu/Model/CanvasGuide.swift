// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

/// A horizontal guide sits at a document Y. A vertical guide sits at a document X.
struct CanvasGuide: Equatable, Sendable, Hashable, Identifiable {
    enum Axis: String, Sendable, Codable {
        case horizontal
        case vertical
    }

    var id: UUID
    var axis: Axis
    var position: Double

    func offset(x: CGFloat, y: CGFloat) -> CanvasGuide {
        var guide = self
        guide.position += Double(axis == .vertical ? x : y)
        return guide
    }

    func scaled(x: CGFloat, y: CGFloat) -> CanvasGuide {
        var guide = self
        guide.position *= Double(axis == .vertical ? x : y)
        return guide
    }

    func mirrored(horizontally: Bool, across center: CGFloat) -> CanvasGuide {
        var guide = self
        if (horizontally && axis == .vertical) || (!horizontally && axis == .horizontal) {
            guide.position = Double(2 * center) - guide.position
        }
        return guide
    }

    /// Turns with the canvas. `canvas` is the size before the quarter turn.
    func quarterTurned(clockwise: Bool, canvas: CGSize) -> CanvasGuide {
        var guide = self
        switch (axis, clockwise) {
        case (.vertical, true):
            guide.axis = .horizontal
        case (.vertical, false):
            guide.axis = .horizontal
            guide.position = Double(canvas.width) - position
        case (.horizontal, true):
            guide.axis = .vertical
            guide.position = Double(canvas.height) - position
        case (.horizontal, false):
            guide.axis = .vertical
        }
        return guide
    }

    func rotated180(canvas: CGSize) -> CanvasGuide {
        var guide = self
        switch axis {
        case .vertical:
            guide.position = Double(canvas.width) - position
        case .horizontal:
            guide.position = Double(canvas.height) - position
        }
        return guide
    }

    /// View-space coordinate of this guide. Vertical guides use `pan.x`; horizontal guides use `pan.y`.
    func viewCoordinate(zoom: CGFloat, pan: CGPoint) -> CGFloat {
        let origin = axis == .vertical ? pan.x : pan.y
        return origin + CGFloat(position) * zoom
    }
}

enum GuideHit {
    /// Nearest guide within `tolerance` view points, using the canvas pan and zoom.
    static func nearest(
        guides: [CanvasGuide],
        viewPoint: CGPoint,
        zoom: CGFloat,
        pan: CGPoint,
        tolerance: CGFloat = 5
    ) -> CanvasGuide? {
        guard zoom > 0 else { return nil }
        var best: (CanvasGuide, CGFloat)?
        for guide in guides {
            let distance: CGFloat
            if guide.axis == .vertical {
                distance = abs(viewPoint.x - (pan.x + CGFloat(guide.position) * zoom))
            } else {
                distance = abs(viewPoint.y - (pan.y + CGFloat(guide.position) * zoom))
            }
            if distance <= tolerance, best.map({ distance < $0.1 }) ?? true {
                best = (guide, distance)
            }
        }
        return best?.0
    }
}

/// Major grid lines every `spacing` pixels, split into `subdivisions`.
struct LayoutGrid: Equatable, Sendable {
    static let spacingRange = 2...4096
    static let subdivisionRange = 1...64

    var spacing: Int
    var subdivisions: Int

    var step: CGFloat { CGFloat(spacing) / CGFloat(max(subdivisions, 1)) }

    init(spacing: Int = 64, subdivisions: Int = 8) {
        let safeSpacing = min(max(spacing, Self.spacingRange.lowerBound), Self.spacingRange.upperBound)
        self.spacing = safeSpacing
        self.subdivisions = min(max(subdivisions, Self.subdivisionRange.lowerBound), Self.subdivisionRange.upperBound, safeSpacing)
    }

    func lines(along length: CGFloat) -> [CGFloat] {
        guard length >= 0, step > 0 else { return [0] }
        let count = Int((length / step + 0.001).rounded(.down))
        return (0...count).map { (CGFloat($0) * step).rounded() }
    }

    func isMajor(_ value: CGFloat) -> Bool {
        abs(value.rounded().truncatingRemainder(dividingBy: CGFloat(spacing))) < 0.001
    }

    /// Nearest grid step within `tolerance`, or nil when the grid is hidden or nothing is close enough.
    func snap(_ value: CGFloat, tolerance: CGFloat, visible: Bool) -> CGFloat? {
        guard visible, step > 0, tolerance >= 0 else { return nil }
        let nearest = (value / step).rounded() * step
        guard abs(nearest - value) <= tolerance + 0.001 else { return nil }
        return nearest
    }
}

enum CanvasRulerMetrics {
    static let thickness: CGFloat = 18

    static func majorStep(pointsPerPixel: CGFloat) -> CGFloat {
        let target = 70 / max(pointsPerPixel, 0.0001)
        let nice: [CGFloat] = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1_000, 2_000, 2_500, 5_000, 10_000]
        return nice.first { $0 >= target } ?? 20_000
    }
}
