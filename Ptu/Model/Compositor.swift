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
        draw(layers: model.layers, into: context, canvasWidth: model.width, canvasHeight: model.height, cache: cache)
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
        layers: [LayerNode],
        into context: CGContext,
        canvasWidth: Int,
        canvasHeight: Int,
        cache: LayerImageCache?
    ) {
        for layer in layers.reversed() {
            draw(layer, into: context, canvasWidth: canvasWidth, canvasHeight: canvasHeight, cache: cache)
        }
    }

    private static func draw(
        _ node: LayerNode,
        into context: CGContext,
        canvasWidth: Int,
        canvasHeight: Int,
        cache: LayerImageCache?
    ) {
        guard node.isVisible, node.opacity > 0 else { return }
        switch node {
        case .pixels(let layer):
            guard let image = cache?.image(for: layer) ?? layer.buffer.cgImage() else { return }
            let destination = CGRect(
                x: CGFloat(layer.originX),
                y: CGFloat(canvasHeight - layer.originY - layer.buffer.height),
                width: CGFloat(layer.buffer.width),
                height: CGFloat(layer.buffer.height)
            )
            context.saveGState()
            context.setAlpha(CGFloat(layer.opacity))
            context.setBlendMode(layer.blend.cgBlendMode)
            context.interpolationQuality = .none
            context.draw(image, in: destination)
            context.restoreGState()
        case .group(let group):
            guard let image = renderGroup(group, canvasWidth: canvasWidth, canvasHeight: canvasHeight, cache: cache) else { return }
            context.saveGState()
            context.setAlpha(CGFloat(group.opacity))
            context.setBlendMode(group.blend.cgBlendMode)
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
            context.restoreGState()
        }
    }

    private static func renderGroup(
        _ group: GroupLayer,
        canvasWidth: Int,
        canvasHeight: Int,
        cache: LayerImageCache?
    ) -> CGImage? {
        guard let context = makeContext(width: canvasWidth, height: canvasHeight) else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        draw(layers: group.children, into: context, canvasWidth: canvasWidth, canvasHeight: canvasHeight, cache: cache)
        return context.makeImage()
    }
}
