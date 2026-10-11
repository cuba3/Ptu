// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

/// Document-space tiles used to invalidate and upload a canvas.
enum CanvasTiles {
    static let side = 256

    /// Tile rectangles covering `dirty`, clipped to the canvas and aligned to `side`.
    static func rects(
        covering dirty: CGRect,
        canvasWidth: Int,
        canvasHeight: Int,
        side: Int = CanvasTiles.side
    ) -> [CGRect] {
        guard canvasWidth > 0, canvasHeight > 0, side > 0 else { return [] }
        let canvas = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
        let area = dirty.standardized.intersection(canvas)
        guard !area.isNull, area.width > 0, area.height > 0 else { return [] }
        let tile = CGFloat(side)
        let minColumn = Int(floor(area.minX / tile))
        let maxColumn = Int(floor((area.maxX - 0.001) / tile))
        let minRow = Int(floor(area.minY / tile))
        let maxRow = Int(floor((area.maxY - 0.001) / tile))
        guard minColumn <= maxColumn, minRow <= maxRow else { return [] }
        var result: [CGRect] = []
        for row in minRow...maxRow {
            for column in minColumn...maxColumn {
                let rect = CGRect(x: column * side, y: row * side, width: side, height: side).intersection(canvas)
                if rect.width > 0, rect.height > 0 {
                    result.append(rect)
                }
            }
        }
        return result
    }

    static func union(_ rects: [CGRect]) -> CGRect? {
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }
}
