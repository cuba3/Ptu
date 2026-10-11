// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class ToolsViewModel {
    let document: EditorDocumentSession

    var tool: EditorTool = .move {
        didSet {
            guard tool != oldValue else { return }
            if tool == .type {
                focusTypeEditor()
            } else {
                typeSession = false
                typeFieldFocused = false
                TextInsertionFocus.set("type-field", active: false)
            }
            endPreviousTool(oldValue)
            if tool == .crop {
                if cropRect == nil {
                    cropRect = canvasBounds
                }
            } else {
                cropRect = nil
                cropDrag = nil
            }
            overlayRevision &+= 1
        }
    }
    var brushSize: Double = 24
    var brushHardness: Double = 0.8
    var brushOpacity: Double = 1
    var selection: PixelSelection? {
        didSet { overlayRevision &+= 1 }
    }
    var selectionDraft: PixelSelection?
    var overlayRevision = 0
    var marqueeShape: MarqueeShape = .rectangle
    var lassoKind: LassoKind = .freehand
    var lassoDraft: [CGPoint] = []
    var lassoCursor: CGPoint?
    var wandTolerance: Double = 32
    var wandContiguous = true
    var sampleAllLayers = false
    var colorFuzziness: Double = 40 {
        didSet { refreshColorRange() }
    }
    var colorInclude: [RGBA] = []
    var colorExclude: [RGBA] = []
    var featherAmount: Double = 8
    var objectEdgeOffset: Double = 0
    var cloneSourcePoint: CGPoint?
    var cloneAligned = true
    var storedCloneOffset: CGSize?
    var blurRadius: Double = 8
    var smudgeMode: SmudgeMode = .smudge
    var healMode = 0
    var shapeKind: ShapeKind = .rectangle
    var shapeCornerRadius: Double = 0
    var shapeLineWidth: Double = 4
    var gradientKind: GradientKind = .linear
    var gradientFade: GradientFade = .toTransparent
    var gradientReversed = false
    var typeText = "" {
        didSet { overlayRevision &+= 1 }
    }
    var typeFontSize: Double = 48
    var typeOrigin: CGPoint?
    /// Keyboard focus is in the sidebar type field.
    var typeFieldFocused = false
    /// Type tool is accepting text, until Escape or another tool. Shortcuts stay off for the whole session.
    var typeSession = false
    /// Bumped so the type field becomes first responder again after the canvas was clicked.
    var typeFocusNonce = 0
    var shapeDraft: ShapeDraft?
    var gradientStart: CGPoint?
    var gradientEnd: CGPoint?
    var floating: FloatingPixels?
    var copiedPixels: CopiedPixels?
    var healDabs: [CGPoint] = []
    var toolMessage: String?
    var hoverPoint: CGPoint?
    var cropRect: CGRect?

    var hasSelection: Bool { selection?.isEmpty == false }
    var canPaste: Bool { copiedPixels != nil }
    /// An active type session or the sidebar type field is accepting characters.
    var isEditingText: Bool { typeSession || typeFieldFocused }

    @ObservationIgnored var selectionAtGesture: PixelSelection?
    @ObservationIgnored var marqueeMode: SelectionMode = .replace
    @ObservationIgnored var movingSelection = false
    @ObservationIgnored var selectionMoveOrigin: PixelSelection?
    @ObservationIgnored var selectionMoveAnchor: CGPoint?
    @ObservationIgnored var floatLast: CGPoint?
    @ObservationIgnored var floatRemainder = CGPoint.zero
    @ObservationIgnored var smudgeCarried: [Float] = []
    @ObservationIgnored var blurredSample: PixelBuffer?
    @ObservationIgnored var cloneSnapshot: PixelBuffer?
    @ObservationIgnored var cloneSnapshotOrigin = CGPoint.zero
    @ObservationIgnored var cloneStrokeOffset: CGSize?

    /// Canvas zoom used to size crop-handle hit targets.
    @ObservationIgnored var interactionZoom: CGFloat = 1
    @ObservationIgnored private var moveLast: CGPoint?
    @ObservationIgnored private var moveRemainder = CGPoint.zero
    @ObservationIgnored private var marqueeAnchor: CGPoint?
    @ObservationIgnored private var cropDrag: CropDrag?
    @ObservationIgnored var lastBrushPoint: CGPoint?

    var showsCropActions: Bool {
        guard tool == .crop, let cropRect else { return false }
        return cropRect.width >= 1 && cropRect.height >= 1
    }

    init(document: EditorDocumentSession) {
        self.document = document
    }

    func resetForNewCanvas() {
        selection = nil
        selectionDraft = nil
        lassoDraft = []
        lassoCursor = nil
        floating = nil
        shapeDraft = nil
        gradientStart = nil
        gradientEnd = nil
        typeOrigin = nil
        typeFieldFocused = false
        typeSession = false
        TextInsertionFocus.set("type-field", active: false)
        healDabs = []
        toolMessage = nil
        cropRect = nil
        cropDrag = nil
    }

    func deleteSelection() {
        guard let selection, !selection.isEmpty, let id = document.selectedLayerID else { return }
        if let area = selection.rectangularArea {
            document.edit(redraw: .rect(area.insetBy(dx: -1, dy: -1))) { model in
                model.clear(selection: area, layerID: id)
            }
            return
        }
        let coverage = selection.resolvedCoverage()
        let slop = selection.feather * 2 + 1
        document.edit(redraw: .rect(selection.bounds.insetBy(dx: -slop, dy: -slop))) { model in
            model.erase(layerID: id, coverage: coverage)
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

    func mouseDown(at point: CGPoint, shift: Bool = false, option: Bool = false, clickCount: Int = 1) {
        hoverPoint = point
        switch tool {
        case .move:
            if floating != nil {
                beginFloatingDrag(at: point)
            } else {
                document.beginCoalescedEdit()
                moveLast = point
                moveRemainder = .zero
            }
        case .marquee:
            beginMarquee(at: point, shift: shift, option: option)
        case .lasso:
            beginLasso(at: point, shift: shift, option: option, clickCount: clickCount)
        case .wand:
            applyWand(at: point, shift: shift, option: option)
        case .objectSelection:
            applyObjectSelection(at: point, shift: shift, option: option)
        case .colorRange:
            sampleColorRange(at: point, shift: shift, option: option)
        case .brush:
            guard let id = document.selectedLayerID, document.model.pixelLayer(id: id) != nil else { return }
            document.beginCoalescedEdit()
            lastBrushPoint = point
            paint([point])
        case .clone:
            beginClone(at: point, option: option)
        case .heal:
            beginHeal(at: point)
        case .blur:
            beginBlur(at: point)
        case .smudge:
            beginSmudge(at: point)
        case .crop:
            beginCrop(at: point)
        case .eyedropper:
            sampleColor(at: point)
        case .type:
            beginType(at: point)
        case .shape:
            beginShape(at: point, shift: shift, option: option)
        case .gradient:
            beginGradient(at: point)
        case .hand, .zoom:
            break
        }
    }

    func mouseDragged(to point: CGPoint, shift: Bool = false, option: Bool = false) {
        hoverPoint = point
        switch tool {
        case .move:
            if floating != nil {
                dragFloating(to: point)
            } else {
                dragMove(to: point)
            }
        case .marquee:
            updateMarquee(to: point, shift: shift)
        case .lasso:
            dragLasso(to: point)
        case .wand, .objectSelection, .colorRange:
            break
        case .brush:
            dragBrush(to: point)
        case .clone:
            dragClone(to: point)
        case .heal:
            dragHeal(to: point)
        case .blur:
            dragBlur(to: point)
        case .smudge:
            dragSmudge(to: point)
        case .crop:
            continueCrop(to: point)
        case .eyedropper:
            sampleColor(at: point)
        case .type:
            break
        case .shape:
            dragShape(to: point, shift: shift, option: option)
        case .gradient:
            dragGradient(to: point)
        case .hand, .zoom:
            break
        }
    }

    func mouseUp(at point: CGPoint, shift: Bool = false, option: Bool = false) {
        hoverPoint = point
        switch tool {
        case .move:
            if floating != nil {
                dragFloating(to: point)
                endFloatingDrag()
            } else {
                dragMove(to: point)
                document.endCoalescedEdit()
                moveLast = nil
            }
        case .marquee:
            updateMarquee(to: point, shift: shift)
            finishMarquee()
        case .lasso:
            finishLasso(at: point, clickCount: 1)
        case .wand, .objectSelection, .colorRange:
            break
        case .brush:
            dragBrush(to: point)
            document.commitPainting()
            document.endCoalescedEdit()
            lastBrushPoint = nil
        case .clone:
            finishClone(at: point)
        case .heal:
            finishHeal(at: point)
        case .blur:
            finishBlur(at: point)
        case .smudge:
            finishSmudge(at: point)
        case .crop:
            continueCrop(to: point)
            finishCropDrag()
        case .eyedropper:
            sampleColor(at: point)
        case .type:
            break
        case .shape:
            finishShape()
        case .gradient:
            finishGradient()
        case .hand, .zoom:
            break
        }
    }

    func hover(at point: CGPoint) {
        hoverPoint = point
        if tool == .lasso, lassoKind == .polygonal, !lassoDraft.isEmpty {
            lassoCursor = point
            overlayRevision &+= 1
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

    private func beginMarquee(at point: CGPoint, shift: Bool, option: Bool) {
        marqueeMode = option ? .subtract : (shift ? .add : .replace)
        if marqueeMode == .replace, let selection, selection.contains(point) {
            movingSelection = true
            selectionMoveOrigin = selection
            selectionMoveAnchor = point
            marqueeAnchor = nil
            return
        }
        movingSelection = false
        marqueeAnchor = point
        selectionAtGesture = marqueeMode == .replace ? nil : selection
        if marqueeMode == .replace {
            selection = nil
        }
    }

    private func updateMarquee(to point: CGPoint, shift: Bool) {
        if movingSelection, let origin = selectionMoveOrigin, let anchor = selectionMoveAnchor {
            let dx = Int((point.x - anchor.x).rounded())
            let dy = Int((point.y - anchor.y).rounded())
            selection = origin.offset(dx: dx, dy: dy)
            return
        }
        guard let anchor = marqueeAnchor else { return }
        var dx = point.x - anchor.x
        var dy = point.y - anchor.y
        if shift {
            let side = max(abs(dx), abs(dy))
            dx = dx < 0 ? -side : side
            dy = dy < 0 ? -side : side
        }
        let rect = CGRect(
            x: min(anchor.x, anchor.x + dx),
            y: min(anchor.y, anchor.y + dy),
            width: abs(dx),
            height: abs(dy)
        )
        let draft = marqueeShape == .ellipse
            ? PixelSelection.ellipse(rect, width: document.model.width, height: document.model.height)
            : PixelSelection.rectangle(rect, width: document.model.width, height: document.model.height)
        if marqueeMode == .replace {
            selection = draft
        } else {
            selectionDraft = draft
            overlayRevision &+= 1
        }
    }

    private func finishMarquee() {
        if movingSelection {
            movingSelection = false
            selectionMoveOrigin = nil
            selectionMoveAnchor = nil
            marqueeAnchor = nil
            return
        }
        if marqueeMode != .replace, let draft = selectionDraft {
            if let base = selectionAtGesture {
                selection = base.combining(draft, mode: marqueeMode)
            } else if marqueeMode == .add {
                selection = draft
            }
        }
        selectionDraft = nil
        marqueeAnchor = nil
        selectionAtGesture = nil
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
        let margin = CGFloat(document.model.pixelLayer(id: id)?.effects.margin ?? 0)
        document.withPaintingModel { live in
            for point in points {
                let rect: CGRect?
                if document.editsMask {
                    rect = live.stampMask(
                        layerID: id,
                        documentCenter: point,
                        radius: radius,
                        hardness: hardness,
                        opacity: opacity,
                        color: color
                    )
                } else {
                    rect = live.stamp(
                        layerID: id,
                        documentCenter: point,
                        radius: radius,
                        hardness: hardness,
                        opacity: opacity,
                        color: color
                    )
                }
                if let rect {
                    dirty = dirty.union(rect)
                }
            }
        }
        guard !dirty.isNull, !dirty.isEmpty else { return }
        document.notePaintDirty(dirty.insetBy(dx: -(margin + 2), dy: -(margin + 2)))
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
