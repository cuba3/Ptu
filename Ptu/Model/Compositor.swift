// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics

/// Flattens a document in sRGB. Index 0 is the front layer.
/// Groups are isolated: children are flattened, then the group is blended as one image.
enum Compositor {
    static func render(_ model: DocumentModel) -> CGImage? {
        guard let context = makeContext(width: model.width, height: model.height) else { return nil }
        draw(model, into: context, documentClip: nil)
        return context.makeImage()
    }

    static func draw(
        _ model: DocumentModel,
        into context: CGContext,
        documentClip: CGRect?,
        cache: LayerImageCache? = nil
    ) {
        let canvas = CGRect(x: 0, y: 0, width: model.width, height: model.height)
        context.saveGState()
        if let documentClip {
            let clip = contextRect(forDocumentRect: documentClip, canvasHeight: model.height).intersection(canvas)
            if clip.isNull || clip.isEmpty {
                context.restoreGState()
                return
            }
            context.clip(to: clip)
            context.clear(clip)
        } else {
            context.clear(canvas)
        }
        draw(model.layers, of: model, into: context, canvasWidth: model.width, canvasHeight: model.height, cache: cache)
        context.restoreGState()
    }

    static func makeContext(width: Int, height: Int) -> CGContext? {
        guard width > 0, height > 0 else { return nil }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    static func contextRect(forDocumentRect documentRect: CGRect, canvasHeight: Int) -> CGRect {
        CGRect(
            x: documentRect.minX,
            y: CGFloat(canvasHeight) - documentRect.maxY,
            width: documentRect.width,
            height: documentRect.height
        )
    }

    private static func draw(
        _ layers: [LayerNode],
        of model: DocumentModel,
        into context: CGContext,
        canvasWidth: Int,
        canvasHeight: Int,
        cache: LayerImageCache?
    ) {
        for layer in layers.reversed() {
            draw(layer, of: model, into: context, canvasWidth: canvasWidth, canvasHeight: canvasHeight, cache: cache)
        }
    }

    private static func draw(
        _ node: LayerNode,
        of model: DocumentModel,
        into context: CGContext,
        canvasWidth: Int,
        canvasHeight: Int,
        cache: LayerImageCache?
    ) {
        guard node.isVisible, node.opacity > 0 else { return }
        switch node {
        case .pixels(let layer):
            let presented = presentedPixels(layer, model: model, cache: cache)
            guard let image = presented.image else { return }
            let destination = CGRect(
                x: CGFloat(presented.originX),
                y: CGFloat(canvasHeight - presented.originY - presented.buffer.height),
                width: CGFloat(presented.buffer.width),
                height: CGFloat(presented.buffer.height)
            )
            context.saveGState()
            context.setAlpha(CGFloat(layer.opacity))
            context.setBlendMode(layer.blend.cgBlendMode)
            context.interpolationQuality = .none
            context.draw(image, in: destination)
            context.restoreGState()
        case .group(let group):
            guard let image = renderGroup(group, model: model, canvasWidth: canvasWidth, canvasHeight: canvasHeight, cache: cache) else { return }
            context.saveGState()
            context.setAlpha(CGFloat(group.opacity))
            context.setBlendMode(group.blend.cgBlendMode)
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
            context.restoreGState()
        case .adjustment(let layer):
            drawAdjustment(layer, of: model, into: context, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        }
    }

    private static func presentedPixels(_ layer: PixelLayer, model: DocumentModel, cache: LayerImageCache?) -> (image: CGImage?, buffer: PixelBuffer, originX: Int, originY: Int) {
        let needsPresentation = layer.mask != nil || layer.maskSourceID != nil || !layer.effects.visible.isEmpty
        guard needsPresentation else {
            return (cache?.image(for: layer) ?? layer.buffer.cgImage(), layer.buffer, layer.originX, layer.originY)
        }
        let presented = LayerPresentation.present(layer, in: model)
        return (presented.buffer.cgImage(), presented.buffer, presented.originX, presented.originY)
    }

    private static func drawAdjustment(
        _ layer: AdjustmentLayer,
        of model: DocumentModel,
        into context: CGContext,
        canvasWidth: Int,
        canvasHeight: Int
    ) {
        guard let snapshot = context.makeImage(), let below = PixelBuffer.from(cgImage: snapshot) else { return }
        let adjusted = layer.adjustment.apply(below)
        var blended = blend(adjusted, over: below, mode: layer.blend, opacity: layer.opacity)
        if let mask = layer.mask {
            blended = LayerPresentation.mix(base: below, top: blended) { x, y in
                mask.coverage(x: x, y: y)
            }
        }
        if let sourceID = layer.maskSourceID {
            blended = LayerPresentation.mix(base: below, top: blended) { x, y in
                LayerPresentation.liveCoverage(model, sourceID: sourceID, x: x, y: y)
            }
        }
        guard let image = blended.cgImage() else { return }
        context.saveGState()
        context.setBlendMode(.copy)
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        context.restoreGState()
    }

    private static func blend(_ top: PixelBuffer, over base: PixelBuffer, mode: BlendMode, opacity: Double) -> PixelBuffer {
        let opacity = min(max(opacity, 0), 1)
        if opacity <= 0 { return base }
        if mode == .normal {
            if opacity >= 1 { return top }
            return LayerPresentation.mix(base: base, top: top) { _, _ in PixelMath.byte(opacity) }
        }
        guard let context = makeContext(width: base.width, height: base.height),
              let baseImage = base.cgImage(),
              let topImage = top.cgImage() else { return top }
        let rect = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        context.draw(baseImage, in: rect)
        context.setAlpha(CGFloat(opacity))
        context.setBlendMode(mode.cgBlendMode)
        context.draw(topImage, in: rect)
        guard let image = context.makeImage(), let blended = PixelBuffer.from(cgImage: image) else { return top }
        return blended
    }

    private static func renderGroup(
        _ group: GroupLayer,
        model: DocumentModel,
        canvasWidth: Int,
        canvasHeight: Int,
        cache: LayerImageCache?
    ) -> CGImage? {
        guard let context = makeContext(width: canvasWidth, height: canvasHeight) else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        draw(group.children, of: model, into: context, canvasWidth: canvasWidth, canvasHeight: canvasHeight, cache: cache)
        guard var image = context.makeImage() else { return nil }
        if let mask = group.mask, let masked = PixelBuffer.from(cgImage: image) {
            image = mask.applying(to: masked).cgImage() ?? image
        }
        return image
    }
}
