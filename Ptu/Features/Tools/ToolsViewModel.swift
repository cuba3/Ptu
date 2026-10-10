// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class ToolsViewModel {
    private let document: EditorDocumentSession

    var tool: EditorTool = .move {
        didSet {
            if tool == .crop {
                if cropRect == nil {
                    cropRect = canvasBounds
                }
            } else {
                cropRect = nil
                cropDrag = nil
            }
        }
    }
    var brushSize: Double = 24
    var brushHardness: Double = 0.8
    var brushOpacity: Double = 1
    var selection: CGRect?
    var cropRect: CGRect?

    /// Canvas zoom used to size crop-handle hit targets.
    @ObservationIgnored var interactionZoom: CGFloat = 1
    @ObservationIgnored private var moveLast: CGPoint?
    @ObservationIgnored private var moveRemainder = CGPoint.zero
    @ObservationIgnored private var marqueeAnchor: CGPoint?
    @ObservationIgnored private var cropDrag: CropDrag?
    @ObservationIgnored private var lastBrushPoint: CGPoint?

    var showsCropActions: Bool {
        guard tool == .crop, let cropRect else { return false }
        return cropRect.width >= 1 && cropRect.height >= 1
    }

    init(document: EditorDocumentSession) {
        self.document = document
    }

    func resetForNewCanvas() {
        selection = nil
        cropRect = nil
        cropDrag = nil
    }

    func deleteSelection() {
        guard let selection, let id = document.selectedLayerID else { return }
        let area = selection.standardized
        guard area.width >= 1, area.height >= 1 else { return }
        document.edit(redraw: .rect(area.insetBy(dx: -1, dy: -1))) { model in
            model.clear(selection: area, layerID: id)
        }
    }

    func applyCrop() {
        guard tool == .crop, let cropRect else { return }
        guard let area = CropPixels.rect(cropRect, canvasWidth: document.model.width, canvasHeight: document.model.height) else { return }
        document.shiftCanvasOrigin(to: CGPoint(x: area.minX, y: area.minY))
        document.edit(redraw: .full) { model in
            model.crop(to: area)
        }
        self.cropRect = CGRect(x: 0, y: 0, width: document.model.width, height: document.model.height)
        cropDrag = nil
        selection = nil
    }

    func cancelCrop() {
        guard tool == .crop else { return }
        cropDrag = nil
        cropRect = canvasBounds
    }

    func mouseDown(at point: CGPoint) {
        switch tool {
        case .move:
            document.beginCoalescedEdit()
            moveLast = point
            moveRemainder = .zero
        case .marquee:
            marqueeAnchor = point
            selection = CGRect(origin: point, size: .zero)
        case .brush:
            guard let id = document.selectedLayerID, document.model.pixelLayer(id: id) != nil else { return }
            document.beginCoalescedEdit()
            lastBrushPoint = point
            paint([point])
        case .crop:
            beginCrop(at: point)
        case .eyedropper:
            sampleColor(at: point)
        }
    }

    func mouseDragged(to point: CGPoint) {
        switch tool {
        case .move:
            dragMove(to: point)
        case .marquee:
            updateMarquee(to: point)
        case .brush:
            dragBrush(to: point)
        case .crop:
            continueCrop(to: point)
        case .eyedropper:
            sampleColor(at: point)
        }
    }

    func mouseUp(at point: CGPoint) {
        switch tool {
        case .move:
            dragMove(to: point)
            document.endCoalescedEdit()
            moveLast = nil
        case .marquee:
            updateMarquee(to: point)
            marqueeAnchor = nil
        case .brush:
            dragBrush(to: point)
            document.commitPainting()
            document.endCoalescedEdit()
            lastBrushPoint = nil
        case .crop:
            continueCrop(to: point)
            finishCropDrag()
        case .eyedropper:
            sampleColor(at: point)
        }
    }

    private var canvasBounds: CGRect {
        CGRect(x: 0, y: 0, width: document.model.width, height: document.model.height)
    }

    private func dragMove(to point: CGPoint) {
        guard let last = moveLast, let id = document.selectedLayerID else { return }
        moveRemainder.x += point.x - last.x
        moveRemainder.y += point.y - last.y
        let dx = Int(moveRemainder.x.rounded(.towardZero))
        let dy = Int(moveRemainder.y.rounded(.towardZero))
        if dx != 0 || dy != 0 {
            moveRemainder.x -= CGFloat(dx)
            moveRemainder.y -= CGFloat(dy)
            document.editLive(redraw: .full) { model in
                model.offset(id: id, dx: dx, dy: dy)
            }
        }
        moveLast = point
    }

    private func updateMarquee(to point: CGPoint) {
        guard let anchor = marqueeAnchor else { return }
        selection = CGRect(
            x: min(anchor.x, point.x),
            y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x),
            height: abs(point.y - anchor.y)
        )
    }

    private func beginCrop(at point: CGPoint) {
        let current = cropRect ?? canvasBounds
        let radius = max(1, 10 / max(interactionZoom, 0.05))
        if let handle = CropHandle.hit(point, rect: current, radius: radius) {
            cropDrag = .resize(handle, original: current)
        } else if current.contains(point) {
            cropDrag = .move(anchor: point, original: current)
        } else {
            cropDrag = .create(anchor: point)
            cropRect = CGRect(origin: point, size: .zero)
        }
    }

    private func continueCrop(to point: CGPoint) {
        guard let cropDrag else { return }
        let canvas = canvasBounds
        switch cropDrag {
        case .create(let anchor):
            cropRect = Self.createdCrop(from: anchor, to: point, canvas: canvas)
        case .move(let anchor, let original):
            cropRect = Self.movedCrop(original, by: CGPoint(x: point.x - anchor.x, y: point.y - anchor.y), canvas: canvas)
        case .resize(let handle, let original):
            cropRect = Self.resizedCrop(original, handle: handle, to: point, canvas: canvas)
        }
    }

    private func finishCropDrag() {
        if let cropRect, let snapped = CropPixels.rect(cropRect, canvasWidth: document.model.width, canvasHeight: document.model.height) {
            self.cropRect = snapped
        } else {
            self.cropRect = canvasBounds
        }
        cropDrag = nil
    }

    private static func createdCrop(from anchor: CGPoint, to point: CGPoint, canvas: CGRect) -> CGRect {
        let rect = CGRect(
            x: min(anchor.x, point.x),
            y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x),
            height: abs(point.y - anchor.y)
        )
        let area = rect.intersection(canvas)
        if area.isNull || area.isEmpty {
            return CGRect(origin: anchor, size: .zero)
        }
        return area
    }

    private static func movedCrop(_ original: CGRect, by delta: CGPoint, canvas: CGRect) -> CGRect {
        var rect = original.offsetBy(dx: delta.x, dy: delta.y)
        if rect.width > canvas.width { rect.size.width = canvas.width }
        if rect.height > canvas.height { rect.size.height = canvas.height }
        if rect.minX < canvas.minX { rect.origin.x = canvas.minX }
        if rect.minY < canvas.minY { rect.origin.y = canvas.minY }
        if rect.maxX > canvas.maxX { rect.origin.x = canvas.maxX - rect.width }
        if rect.maxY > canvas.maxY { rect.origin.y = canvas.maxY - rect.height }
        return rect
    }

    private static func resizedCrop(_ original: CGRect, handle: CropHandle, to point: CGPoint, canvas: CGRect) -> CGRect {
        var minX = original.minX
        var minY = original.minY
        var maxX = original.maxX
        var maxY = original.maxY
        if handle.movesMinX { minX = point.x }
        if handle.movesMaxX { maxX = point.x }
        if handle.movesMinY { minY = point.y }
        if handle.movesMaxY { maxY = point.y }
        minX = min(max(minX, canvas.minX), canvas.maxX - 1)
        minY = min(max(minY, canvas.minY), canvas.maxY - 1)
        maxX = min(max(maxX, canvas.minX + 1), canvas.maxX)
        maxY = min(max(maxY, canvas.minY + 1), canvas.maxY)
        if maxX < minX + 1 {
            if handle.movesMinX { minX = maxX - 1 } else { maxX = minX + 1 }
        }
        if maxY < minY + 1 {
            if handle.movesMinY { minY = maxY - 1 } else { maxY = minY + 1 }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func dragBrush(to point: CGPoint) {
        guard let last = lastBrushPoint else { return }
        let radius = CGFloat(brushSize) / 2
        let spacing = max(1, radius * 0.25)
        let distance = hypot(point.x - last.x, point.y - last.y)
        let steps = max(1, Int((distance / spacing).rounded(.up)))
        var points: [CGPoint] = []
        points.reserveCapacity(steps)
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            points.append(CGPoint(
                x: last.x + (point.x - last.x) * t,
                y: last.y + (point.y - last.y) * t
            ))
        }
        lastBrushPoint = point
        paint(points)
    }

    private func paint(_ points: [CGPoint]) {
        guard let id = document.selectedLayerID, !points.isEmpty else { return }
        let radius = CGFloat(brushSize) / 2
        let hardness = brushHardness
        let opacity = brushOpacity
        let color = document.foreground.opaque
        var dirty = CGRect.null
        document.withPaintingModel { live in
            for point in points {
                if let rect = live.stamp(
                    layerID: id,
                    documentCenter: point,
                    radius: radius,
                    hardness: hardness,
                    opacity: opacity,
                    color: color
                ) {
                    dirty = dirty.union(rect)
                }
            }
        }
        guard !dirty.isNull, !dirty.isEmpty else { return }
        document.notePaintDirty(dirty.insetBy(dx: -2, dy: -2))
    }

    private func sampleColor(at point: CGPoint) {
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard x >= 0, y >= 0, x < document.model.width, y < document.model.height,
              let image = Compositor.render(document.model),
              let buffer = PixelBuffer.from(cgImage: image) else { return }
        let pixel = buffer.pixel(x: x, y: y)
        guard pixel.a > 0 else { return }
        document.foreground = pixel.opaque
    }
}

private enum CropDrag {
    case create(anchor: CGPoint)
    case move(anchor: CGPoint, original: CGRect)
    case resize(CropHandle, original: CGRect)
}

enum CropHandle {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var movesMinX: Bool {
        self == .topLeft || self == .left || self == .bottomLeft
    }

    var movesMaxX: Bool {
        self == .topRight || self == .right || self == .bottomRight
    }

    var movesMinY: Bool {
        self == .topLeft || self == .top || self == .topRight
    }

    var movesMaxY: Bool {
        self == .bottomLeft || self == .bottom || self == .bottomRight
    }

    static func hit(_ point: CGPoint, rect: CGRect, radius: CGFloat) -> CropHandle? {
        let nearLeft = abs(point.x - rect.minX) <= radius
        let nearRight = abs(point.x - rect.maxX) <= radius
        let nearTop = abs(point.y - rect.minY) <= radius
        let nearBottom = abs(point.y - rect.maxY) <= radius
        let inX = point.x >= rect.minX - radius && point.x <= rect.maxX + radius
        let inY = point.y >= rect.minY - radius && point.y <= rect.maxY + radius
        if nearLeft && nearTop && inX && inY { return .topLeft }
        if nearRight && nearTop && inX && inY { return .topRight }
        if nearLeft && nearBottom && inX && inY { return .bottomLeft }
        if nearRight && nearBottom && inX && inY { return .bottomRight }
        if nearTop && inX { return .top }
        if nearBottom && inX { return .bottom }
        if nearLeft && inY { return .left }
        if nearRight && inY { return .right }
        return nil
    }
}
