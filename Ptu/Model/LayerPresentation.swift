// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

struct PresentedPixels: Equatable, Sendable {
    var buffer: PixelBuffer
    var originX: Int
    var originY: Int
}

enum LayerPresentation {
    static func present(_ layer: PixelLayer, in model: DocumentModel) -> PresentedPixels {
        var shown = layer.buffer
        if let mask = layer.mask {
            shown = mask.applying(to: shown)
        }
        if let sourceID = layer.maskSourceID {
            shown = applyLiveMask(shown, sourceID: sourceID, originX: layer.originX, originY: layer.originY, model: model)
        }
        let rendered = LayerEffectsRenderer.render(shown, effects: layer.effects)
        return PresentedPixels(
            buffer: rendered.buffer,
            originX: layer.originX - rendered.inset,
            originY: layer.originY - rendered.inset
        )
    }

    static func mix(base: PixelBuffer, top: PixelBuffer, coverage: (Int, Int) -> UInt8) -> PixelBuffer {
        var result = base
        result.updateEach { x, y, pixel in
            let amount = Int(coverage(x, y))
            if amount >= 255 {
                pixel = top.pixel(x: x, y: y)
                return
            }
            if amount <= 0 { return }
            let over = top.pixel(x: x, y: y)
            let t = Double(amount) / 255
            pixel = RGBA(
                r: PixelMath.byte(PixelMath.unit(pixel.r) * (1 - t) + PixelMath.unit(over.r) * t),
                g: PixelMath.byte(PixelMath.unit(pixel.g) * (1 - t) + PixelMath.unit(over.g) * t),
                b: PixelMath.byte(PixelMath.unit(pixel.b) * (1 - t) + PixelMath.unit(over.b) * t),
                a: PixelMath.byte(PixelMath.unit(pixel.a) * (1 - t) + PixelMath.unit(over.a) * t)
            )
        }
        return result
    }

    static func liveCoverage(_ model: DocumentModel, sourceID: UUID, x: Int, y: Int) -> UInt8 {
        guard let source = model.pixelLayer(id: sourceID) else { return 255 }
        let localX = x - source.originX
        let localY = y - source.originY
        var alpha = Int(source.buffer.pixel(x: localX, y: localY).a)
        if let mask = source.mask {
            alpha = (alpha * Int(mask.coverage(x: localX, y: localY)) + 127) / 255
        }
        return UInt8(clamping: alpha)
    }

    private static func applyLiveMask(
        _ buffer: PixelBuffer,
        sourceID: UUID,
        originX: Int,
        originY: Int,
        model: DocumentModel
    ) -> PixelBuffer {
        var result = buffer
        result.updateEach { x, y, pixel in
            let coverage = Int(liveCoverage(model, sourceID: sourceID, x: originX + x, y: originY + y))
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
