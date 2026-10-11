// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

struct CopiedPixels: Equatable, Sendable {
    var pixels: PixelBuffer
    var originX: Int
    var originY: Int
}

struct FloatingPixels: Equatable, Sendable {
    var pixels: PixelBuffer
    var coverage: [UInt8]
    var originX: Int
    var originY: Int
    var layerID: UUID
}

enum SelectionClipboard {
    static func copy(layer: PixelLayer, selection: PixelSelection) -> CopiedPixels? {
        guard let region = SelectionClipboardCrop.cropped(layer: layer, selection: selection, clearSource: false) else { return nil }
        return CopiedPixels(pixels: region.pixels, originX: region.originX, originY: region.originY)
    }

    static func copyLayer(_ layer: PixelLayer) -> CopiedPixels {
        CopiedPixels(pixels: layer.buffer, originX: layer.originX, originY: layer.originY)
    }
}

enum FloatingSelection {
    struct Lift: Equatable, Sendable {
        var floating: FloatingPixels
        var cleared: PixelBuffer
    }

    static func lift(layer: PixelLayer, selection: PixelSelection) -> Lift? {
        guard let region = SelectionClipboardCrop.cropped(layer: layer, selection: selection, clearSource: true) else { return nil }
        return Lift(
            floating: FloatingPixels(
                pixels: region.pixels,
                coverage: region.coverage,
                originX: region.originX,
                originY: region.originY,
                layerID: layer.id
            ),
            cleared: region.cleared
        )
    }

    static func stamp(_ floating: FloatingPixels, into layer: inout PixelLayer) {
        let destMinX = min(layer.originX, floating.originX)
        let destMinY = min(layer.originY, floating.originY)
        let destMaxX = max(layer.originX + layer.buffer.width, floating.originX + floating.pixels.width)
        let destMaxY = max(layer.originY + layer.buffer.height, floating.originY + floating.pixels.height)
        let width = max(1, destMaxX - destMinX)
        let height = max(1, destMaxY - destMinY)
        var canvas = PixelBuffer(width: width, height: height, fill: .clear)
        canvas.blit(layer.buffer, atX: layer.originX - destMinX, y: layer.originY - destMinY)
        for y in 0..<floating.pixels.height {
            for x in 0..<floating.pixels.width {
                let index = y * floating.pixels.width + x
                let coverage = index < floating.coverage.count ? CGFloat(floating.coverage[index]) / 255 : 1
                guard coverage > 0 else { continue }
                let color = floating.pixels.pixel(x: x, y: y)
                canvas.paint(
                    color,
                    x: floating.originX - destMinX + x,
                    y: floating.originY - destMinY + y,
                    coverage: coverage
                )
            }
        }
        layer.buffer = canvas
        layer.originX = destMinX
        layer.originY = destMinY
    }
}

enum SelectionClipboardCrop {
    struct Region: Equatable, Sendable {
        var pixels: PixelBuffer
        var coverage: [UInt8]
        var cleared: PixelBuffer
        var originX: Int
        var originY: Int
    }

    static func cropped(layer: PixelLayer, selection: PixelSelection, clearSource: Bool) -> Region? {
        let coverage = selection.resolvedCoverage()
        guard coverage.count == selection.width * selection.height else { return nil }
        let area = selection.bounds.intersection(layer.bounds)
        guard area.width >= 1, area.height >= 1 else { return nil }
        let minX = Int(floor(area.minX))
        let minY = Int(floor(area.minY))
        let maxX = Int(ceil(area.maxX))
        let maxY = Int(ceil(area.maxY))
        let cropWidth = maxX - minX
        let cropHeight = maxY - minY
        guard cropWidth >= 1, cropHeight >= 1 else { return nil }
        var bytes = [UInt8](repeating: 0, count: cropWidth * cropHeight * 4)
        var weights = [UInt8](repeating: 0, count: cropWidth * cropHeight)
        var cleared = layer.buffer
        var kept = false
        for y in minY..<maxY {
            for x in minX..<maxX {
                guard y >= 0, x >= 0, y < selection.height, x < selection.width else { continue }
                let weight = coverage[y * selection.width + x]
                guard weight > 0 else { continue }
                let localX = x - layer.originX
                let localY = y - layer.originY
                let pixel = layer.buffer.pixel(x: localX, y: localY)
                guard pixel.a > 0 else { continue }
                kept = true
                let destination = ((y - minY) * cropWidth + (x - minX)) * 4
                let scale = CGFloat(weight) / 255
                bytes[destination] = pixel.r
                bytes[destination + 1] = pixel.g
                bytes[destination + 2] = pixel.b
                bytes[destination + 3] = UInt8(clamping: Int((CGFloat(pixel.a) * scale).rounded()))
                weights[(y - minY) * cropWidth + (x - minX)] = weight
                if clearSource {
                    let keep = 1 - scale
                    let faded = RGBA(
                        r: pixel.r,
                        g: pixel.g,
                        b: pixel.b,
                        a: UInt8(clamping: Int((CGFloat(pixel.a) * keep).rounded()))
                    )
                    cleared.setPixel(x: localX, y: localY, rgba: faded.a == 0 ? .clear : faded)
                }
            }
        }
        guard kept else { return nil }
        return Region(
            pixels: PixelBuffer(bytes: bytes, width: cropWidth, height: cropHeight),
            coverage: weights,
            cleared: cleared,
            originX: minX,
            originY: minY
        )
    }
}
