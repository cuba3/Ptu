// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum CanvasResize {
    /// Anchor 0 is top-left through 8 bottom-right, row-major. Extra pixels grow away from the anchor.
    static func offset(oldWidth: Int, oldHeight: Int, newWidth: Int, newHeight: Int, anchor: Int) -> (x: Int, y: Int) {
        let anchor = min(max(anchor, 0), 8)
        let x = Int(floor(Double(newWidth - oldWidth) * Double(anchor % 3) / 2))
        let y = Int(floor(Double(newHeight - oldHeight) * Double(anchor / 3) / 2))
        return (x, y)
    }
}

extension DocumentModel {
    func trimRect(options: TrimOptions) -> CGRect? {
        guard let image = Compositor.render(self), let buffer = PixelBuffer.from(cgImage: image) else { return nil }
        return ImageTrim.bounds(in: buffer, options: options)
    }

    mutating func flipLayer(id: UUID, horizontally: Bool) {
        guard let node = node(id: id) else { return }
        switch node {
        case .pixels(var layer):
            flipRaster(&layer, horizontally: horizontally)
            update(id: id) { $0 = .pixels(layer) }
        case .group:
            let members = pixelDescendants(of: node)
            let box = unionBounds(members)
            guard !box.isNull else { return }
            let axis = horizontally ? box.midX : box.midY
            for member in members {
                update(id: member.id) { node in
                    guard case .pixels(var layer) = node else { return }
                    if horizontally {
                        layer.buffer = layer.buffer.flippedHorizontally()
                        layer.mask = Self.flippedMask(layer.mask, horizontally: true)
                        layer.originX = Int((2 * axis - CGFloat(layer.originX + layer.buffer.width)).rounded())
                    } else {
                        layer.buffer = layer.buffer.flippedVertically()
                        layer.mask = Self.flippedMask(layer.mask, horizontally: false)
                        layer.originY = Int((2 * axis - CGFloat(layer.originY + layer.buffer.height)).rounded())
                    }
                    node = .pixels(layer)
                }
            }
        case .adjustment:
            break
        }
    }

    mutating func flipCanvas(horizontally: Bool) {
        let canvasWidth = width
        let canvasHeight = height
        let axis = CGFloat(horizontally ? canvasWidth : canvasHeight) / 2
        updateEachNode { node in
            switch node {
            case .pixels(var layer):
                if horizontally {
                    layer.buffer = layer.buffer.flippedHorizontally()
                    layer.mask = Self.flippedMask(layer.mask, horizontally: true)
                    layer.originX = canvasWidth - layer.originX - layer.buffer.width
                } else {
                    layer.buffer = layer.buffer.flippedVertically()
                    layer.mask = Self.flippedMask(layer.mask, horizontally: false)
                    layer.originY = canvasHeight - layer.originY - layer.buffer.height
                }
                node = .pixels(layer)
            case .group(var group):
                group.mask = Self.transformedCanvasMask(group.mask, canvasWidth: canvasWidth, canvasHeight: canvasHeight) {
                    horizontally ? $0.flippedHorizontally() : $0.flippedVertically()
                }
                node = .group(group)
            case .adjustment(var layer):
                layer.mask = Self.transformedCanvasMask(layer.mask, canvasWidth: canvasWidth, canvasHeight: canvasHeight) {
                    horizontally ? $0.flippedHorizontally() : $0.flippedVertically()
                }
                node = .adjustment(layer)
            }
        }
        guides = guides.map { $0.mirrored(horizontally: horizontally, across: axis) }
    }

    /// `quarters` is clockwise. 1, -3, and 5 are the same turn.
    mutating func rotateCanvas(quarters: Int) {
        let steps = ((quarters % 4) + 4) % 4
        switch steps {
        case 1: rotateQuarter(clockwise: true)
        case 2: rotateHalf()
        case 3: rotateQuarter(clockwise: false)
        default: break
        }
    }

    mutating func resizeCanvas(toWidth newWidth: Int, height newHeight: Int, anchor: Int) {
        let newWidth = min(max(newWidth, DocumentModel.minimumSide), DocumentModel.maximumSide)
        let newHeight = min(max(newHeight, DocumentModel.minimumSide), DocumentModel.maximumSide)
        let shift = CanvasResize.offset(oldWidth: width, oldHeight: height, newWidth: newWidth, newHeight: newHeight, anchor: anchor)
        let oldWidth = width
        let oldHeight = height
        updateEachNode { node in
            switch node {
            case .pixels(var layer):
                layer.originX += shift.x
                layer.originY += shift.y
                node = .pixels(layer)
            case .group(var group):
                group.mask = Self.movedCanvasMask(group.mask, oldWidth: oldWidth, oldHeight: oldHeight, newWidth: newWidth, newHeight: newHeight, dx: shift.x, dy: shift.y)
                node = .group(group)
            case .adjustment(var layer):
                layer.mask = Self.movedCanvasMask(layer.mask, oldWidth: oldWidth, oldHeight: oldHeight, newWidth: newWidth, newHeight: newHeight, dx: shift.x, dy: shift.y)
                node = .adjustment(layer)
            }
        }
        guides = guides.map { $0.offset(x: CGFloat(shift.x), y: CGFloat(shift.y)) }
        width = newWidth
        height = newHeight
    }

    mutating func resizeImage(toWidth newWidth: Int, height newHeight: Int, resolutionPPI: Double, sampling: LayerSampling) {
        let newWidth = min(max(newWidth, DocumentModel.minimumSide), DocumentModel.maximumSide)
        let newHeight = min(max(newHeight, DocumentModel.minimumSide), DocumentModel.maximumSide)
        let oldWidth = width
        let oldHeight = height
        let scaleX = CGFloat(newWidth) / CGFloat(max(oldWidth, 1))
        let scaleY = CGFloat(newHeight) / CGFloat(max(oldHeight, 1))
        updateEachNode { node in
            switch node {
            case .pixels(var layer):
                let scaledWidth = max(1, Int((CGFloat(layer.buffer.width) * scaleX).rounded()))
                let scaledHeight = max(1, Int((CGFloat(layer.buffer.height) * scaleY).rounded()))
                layer.buffer = layer.buffer.resampled(toWidth: scaledWidth, height: scaledHeight, sampling: sampling)
                if var mask = layer.mask {
                    mask.buffer = mask.buffer.resampled(toWidth: scaledWidth, height: scaledHeight, sampling: sampling)
                    layer.mask = mask
                }
                layer.originX = Int((CGFloat(layer.originX) * scaleX).rounded())
                layer.originY = Int((CGFloat(layer.originY) * scaleY).rounded())
                node = .pixels(layer)
            case .group(var group):
                group.mask = Self.scaledCanvasMask(group.mask, oldWidth: oldWidth, oldHeight: oldHeight, newWidth: newWidth, newHeight: newHeight, sampling: sampling)
                node = .group(group)
            case .adjustment(var layer):
                layer.mask = Self.scaledCanvasMask(layer.mask, oldWidth: oldWidth, oldHeight: oldHeight, newWidth: newWidth, newHeight: newHeight, sampling: sampling)
                node = .adjustment(layer)
            }
        }
        guides = guides.map { $0.scaled(x: scaleX, y: scaleY) }
        width = newWidth
        height = newHeight
        self.resolutionPPI = min(max(resolutionPPI, 1), 2400)
    }

    mutating func replaceLayerRaster(id: UUID, buffer: PixelBuffer, originX: Int, originY: Int) {
        update(id: id) { node in
            guard case .pixels(var layer) = node else { return }
            if var mask = layer.mask, mask.buffer.width != buffer.width || mask.buffer.height != buffer.height {
                mask.buffer = mask.buffer.resampled(toWidth: buffer.width, height: buffer.height, sampling: .smooth)
                layer.mask = mask
            }
            layer.buffer = buffer
            layer.originX = originX
            layer.originY = originY
            node = .pixels(layer)
        }
    }

    private mutating func rotateQuarter(clockwise: Bool) {
        let canvasWidth = width
        let canvasHeight = height
        let canvas = CGSize(width: canvasWidth, height: canvasHeight)
        updateEachNode { node in
            switch node {
            case .pixels(var layer):
                if clockwise {
                    let originX = canvasHeight - layer.originY - layer.buffer.height
                    let originY = layer.originX
                    layer.buffer = layer.buffer.rotatedClockwise()
                    layer.mask = Self.rotatedMask(layer.mask, clockwise: true)
                    layer.originX = originX
                    layer.originY = originY
                } else {
                    let originX = layer.originY
                    let originY = canvasWidth - layer.originX - layer.buffer.width
                    layer.buffer = layer.buffer.rotatedCounterclockwise()
                    layer.mask = Self.rotatedMask(layer.mask, clockwise: false)
                    layer.originX = originX
                    layer.originY = originY
                }
                node = .pixels(layer)
            case .group(var group):
                group.mask = Self.transformedCanvasMask(group.mask, canvasWidth: canvasWidth, canvasHeight: canvasHeight) {
                    clockwise ? $0.rotatedClockwise() : $0.rotatedCounterclockwise()
                }
                node = .group(group)
            case .adjustment(var layer):
                layer.mask = Self.transformedCanvasMask(layer.mask, canvasWidth: canvasWidth, canvasHeight: canvasHeight) {
                    clockwise ? $0.rotatedClockwise() : $0.rotatedCounterclockwise()
                }
                node = .adjustment(layer)
            }
        }
        guides = guides.map { $0.quarterTurned(clockwise: clockwise, canvas: canvas) }
        width = canvasHeight
        height = canvasWidth
    }

    private mutating func rotateHalf() {
        let canvasWidth = width
        let canvasHeight = height
        let canvas = CGSize(width: canvasWidth, height: canvasHeight)
        updateEachNode { node in
            switch node {
            case .pixels(var layer):
                let originX = canvasWidth - layer.originX - layer.buffer.width
                let originY = canvasHeight - layer.originY - layer.buffer.height
                layer.buffer = layer.buffer.rotated180()
                layer.mask = layer.mask.map { mask in
                    var mask = mask
                    mask.buffer = mask.buffer.rotated180()
                    return mask
                }
                layer.originX = originX
                layer.originY = originY
                node = .pixels(layer)
            case .group(var group):
                group.mask = Self.transformedCanvasMask(group.mask, canvasWidth: canvasWidth, canvasHeight: canvasHeight) { $0.rotated180() }
                node = .group(group)
            case .adjustment(var layer):
                layer.mask = Self.transformedCanvasMask(layer.mask, canvasWidth: canvasWidth, canvasHeight: canvasHeight) { $0.rotated180() }
                node = .adjustment(layer)
            }
        }
        guides = guides.map { $0.rotated180(canvas: canvas) }
    }

    private func pixelDescendants(of node: LayerNode) -> [PixelLayer] {
        switch node {
        case .pixels(let layer):
            [layer]
        case .group(let group):
            group.children.flatMap { pixelDescendants(of: $0) }
        case .adjustment:
            []
        }
    }

    private func unionBounds(_ layers: [PixelLayer]) -> CGRect {
        layers.reduce(CGRect.null) { $0.union($1.bounds) }
    }

    private func flipRaster(_ layer: inout PixelLayer, horizontally: Bool) {
        if horizontally {
            layer.buffer = layer.buffer.flippedHorizontally()
            layer.mask = Self.flippedMask(layer.mask, horizontally: true)
        } else {
            layer.buffer = layer.buffer.flippedVertically()
            layer.mask = Self.flippedMask(layer.mask, horizontally: false)
        }
    }

    private static func flippedMask(_ mask: LayerMask?, horizontally: Bool) -> LayerMask? {
        guard var mask else { return nil }
        mask.buffer = horizontally ? mask.buffer.flippedHorizontally() : mask.buffer.flippedVertically()
        return mask
    }

    private static func rotatedMask(_ mask: LayerMask?, clockwise: Bool) -> LayerMask? {
        guard var mask else { return nil }
        mask.buffer = clockwise ? mask.buffer.rotatedClockwise() : mask.buffer.rotatedCounterclockwise()
        return mask
    }

    private static func transformedCanvasMask(
        _ mask: LayerMask?,
        canvasWidth: Int,
        canvasHeight: Int,
        _ body: (PixelBuffer) -> PixelBuffer
    ) -> LayerMask? {
        guard var mask, mask.buffer.width == canvasWidth, mask.buffer.height == canvasHeight else { return mask }
        mask.buffer = body(mask.buffer)
        return mask
    }

    private static func movedCanvasMask(
        _ mask: LayerMask?,
        oldWidth: Int,
        oldHeight: Int,
        newWidth: Int,
        newHeight: Int,
        dx: Int,
        dy: Int
    ) -> LayerMask? {
        guard var mask, mask.buffer.width == oldWidth, mask.buffer.height == oldHeight else { return mask }
        var moved = PixelBuffer(width: newWidth, height: newHeight, fill: .white)
        let source = mask.buffer.copyBytes()
        for y in 0..<oldHeight {
            let destinationY = y + dy
            guard destinationY >= 0, destinationY < newHeight else { continue }
            for x in 0..<oldWidth {
                let destinationX = x + dx
                guard destinationX >= 0, destinationX < newWidth else { continue }
                let color = RGBA(
                    r: source[(y * oldWidth + x) * 4],
                    g: source[(y * oldWidth + x) * 4 + 1],
                    b: source[(y * oldWidth + x) * 4 + 2],
                    a: source[(y * oldWidth + x) * 4 + 3]
                )
                moved.setPixel(x: destinationX, y: destinationY, rgba: color)
            }
        }
        mask.buffer = moved
        return mask
    }

    private static func scaledCanvasMask(
        _ mask: LayerMask?,
        oldWidth: Int,
        oldHeight: Int,
        newWidth: Int,
        newHeight: Int,
        sampling: LayerSampling
    ) -> LayerMask? {
        guard var mask, mask.buffer.width == oldWidth, mask.buffer.height == oldHeight else { return mask }
        mask.buffer = mask.buffer.resampled(toWidth: newWidth, height: newHeight, sampling: sampling)
        return mask
    }

    private mutating func updateEachNode(_ body: (inout LayerNode) -> Void) {
        func walk(_ nodes: inout [LayerNode]) {
            for index in nodes.indices {
                if case .group(var group) = nodes[index] {
                    walk(&group.children)
                    nodes[index] = .group(group)
                }
                body(&nodes[index])
            }
        }
        walk(&layers)
    }
}
