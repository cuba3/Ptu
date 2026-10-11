// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation
import Observation

enum CanvasDisplayDirty: Equatable {
    case none
    case full
    case rect(CGRect)
}

@MainActor
@Observable
final class CanvasViewModel {
    static let minimumZoom: CGFloat = 0.0625
    static let maximumZoom: CGFloat = 32

    let tools: ToolsViewModel
    private let document: EditorDocumentSession

    private(set) var zoom: CGFloat = 1
    private(set) var zoomRequestID = 0

    @ObservationIgnored private(set) var pan: CGPoint = .zero
    @ObservationIgnored private(set) var compositeImage: CGImage?
    @ObservationIgnored private var zoomRequest: ZoomRequest?
    @ObservationIgnored private var compositeContext: CGContext?
    @ObservationIgnored private let layerCache = LayerImageCache()
    @ObservationIgnored private var appliedRenderGeneration = 0
    @ObservationIgnored private var appliedZoomRequestID = 0
    @ObservationIgnored private var didFitInitially = false
    @ObservationIgnored private var bounds: CGRect = .zero
    @ObservationIgnored private var compositeToken = 0
    @ObservationIgnored private var appliedCompositeToken = 0
    @ObservationIgnored private var pendingMetalFull = true
    @ObservationIgnored private var pendingMetalRect: CGRect = .null
    @ObservationIgnored private var guideDraft: GuideDraft?
    @ObservationIgnored private var transformDrag: TransformDrag?
    @ObservationIgnored private(set) var transformImage: CGImage?

    private(set) var displayGeneration = 0
    var showsRulers = false
    var showsGuides = true
    var showsGrid = false
    var snapEnabled = true
    var grid = LayoutGrid()
    var transform: TransformSession?

    var zoomPercent: Int { Int((zoom * 100).rounded()) }
    var contentWidth: CGFloat { CGFloat(document.model.width) }
    var contentHeight: CGFloat { CGFloat(document.model.height) }
    var isTransforming: Bool { transform != nil }
    var rulerInset: CGFloat { showsRulers ? CanvasRulerMetrics.thickness : 0 }
    var displayedGuides: [CanvasGuide] {
        var guides = document.model.guides
        guard let guideDraft else { return guides }
        let current = CanvasGuide(id: guideDraft.id, axis: guideDraft.axis, position: guideDraft.position)
        if let index = guides.firstIndex(where: { $0.id == guideDraft.id }) {
            guides[index] = current
        } else if guideDraft.isNew {
            guides.append(current)
        }
        return guides
    }

    init(document: EditorDocumentSession, tools: ToolsViewModel) {
        self.document = document
        self.tools = tools
        tools.interactionZoom = zoom
    }

    func requestZoom(_ request: ZoomRequest) {
        zoomRequest = request
        zoomRequestID += 1
    }

    func sync(bounds: CGRect) {
        self.bounds = bounds
        if let shift = document.consumeCanvasOriginShift() {
            pan.x += shift.x * zoom
            pan.y += shift.y * zoom
        }
        if zoomRequestID != appliedZoomRequestID {
            appliedZoomRequestID = zoomRequestID
            let anchor = CGPoint(x: contentBounds.midX, y: contentBounds.midY)
            switch zoomRequest {
            case .zoomIn:
                zoom(by: 1.25, anchor: anchor)
            case .zoomOut:
                zoom(by: 0.8, anchor: anchor)
            case .actualSize:
                setZoom(1, anchor: anchor)
            case .fit, nil:
                fitToWindow()
            }
        }
        if !didFitInitially, bounds.width > 40, bounds.height > 40 {
            didFitInitially = true
            fitToWindow()
        }
        if needsCompositeRefresh() {
            _ = refreshPixels(allowEmpty: true)
        }
    }

    func layout(bounds: CGRect) -> Bool {
        self.bounds = bounds
        guard bounds.width > 40, bounds.height > 40 else { return false }
        var needsDisplay = false
        if !didFitInitially {
            didFitInitially = true
            fitToWindow()
            needsDisplay = true
        }
        if needsCompositeRefresh() {
            _ = refreshPixels(allowEmpty: true)
            needsDisplay = true
        }
        return needsDisplay
    }

    func refreshPixels(allowEmpty: Bool) -> CanvasDisplayDirty {
        var model = document.canvasModel()
        if let hidden = transform?.layerID {
            model.setOpacity(id: hidden, opacity: 0)
        }
        let dirty = document.consumeDirty()
        let sizeChanged = compositeContext?.width != model.width || compositeContext?.height != model.height
        let full = dirty.full || sizeChanged || compositeContext == nil || model.prefersFullRedraw || appliedCompositeToken != compositeToken
        if !full && (dirty.rect.isNull || dirty.rect.isEmpty) {
            if allowEmpty, compositeImage == nil || sizeChanged {
                updateComposite(model: model, full: true, rect: .null)
                appliedRenderGeneration = document.renderGeneration
                appliedCompositeToken = compositeToken
                return .full
            }
            return .none
        }
        if full {
            layerCache.invalidate()
        } else if let id = document.selectedLayerID, let layer = model.pixelLayer(id: id) {
            let local = dirty.rect.offsetBy(dx: -CGFloat(layer.originX), dy: -CGFloat(layer.originY))
            layerCache.prepare(layer, dirty: local)
        }
        updateComposite(model: model, full: full, rect: dirty.rect)
        appliedRenderGeneration = document.renderGeneration
        appliedCompositeToken = compositeToken
        if full {
            return .full
        }
        return .rect(viewRect(for: dirty.rect).insetBy(dx: -2, dy: -2))
    }

    func scroll(
        deltaX: CGFloat,
        deltaY: CGFloat,
        precise: Bool,
        inverted: Bool,
        commandPressed: Bool,
        anchor: CGPoint,
        bounds: CGRect
    ) {
        self.bounds = bounds
        if commandPressed {
            let delta = precise ? deltaY : deltaY * 4
            zoom(by: exp(-delta * 0.01), anchor: anchor)
            return
        }
        let scale: CGFloat = precise ? 1 : 12
        let direction: CGFloat = inverted ? -1 : 1
        pan.x += deltaX * scale * direction
        pan.y -= deltaY * scale * direction
    }

    func magnify(by magnification: CGFloat, anchor: CGPoint) {
        zoom(by: 1 + magnification, anchor: anchor)
    }

    func documentPoint(from viewPoint: CGPoint) -> CGPoint {
        documentPoint(from: viewPoint, zoom: zoom, pan: pan)
    }

    func viewPoint(from documentPoint: CGPoint) -> CGPoint {
        CGPoint(x: pan.x + documentPoint.x * zoom, y: pan.y + documentPoint.y * zoom)
    }

    func viewRect(for documentRect: CGRect) -> CGRect {
        CGRect(
            x: pan.x + documentRect.minX * zoom,
            y: pan.y + documentRect.minY * zoom,
            width: documentRect.width * zoom,
            height: documentRect.height * zoom
        )
    }

    private func fitToWindow() {
        let content = contentBounds
        guard content.width > 40, content.height > 40 else { return }
        let documentWidth = contentWidth
        let documentHeight = contentHeight
        guard documentWidth > 0, documentHeight > 0 else { return }
        let scale = min((content.width - 40) / documentWidth, (content.height - 40) / documentHeight)
        assignZoom(min(max(scale, Self.minimumZoom), Self.maximumZoom))
        pan = CGPoint(
            x: content.minX + (content.width - documentWidth * zoom) / 2,
            y: content.minY + (content.height - documentHeight * zoom) / 2
        )
    }

    func setZoom(_ newZoom: CGFloat, anchor: CGPoint) {
        let factor = newZoom / max(zoom, 0.0001)
        zoom(by: factor, anchor: anchor)
    }

    func zoom(by factor: CGFloat, anchor: CGPoint) {
        let oldZoom = zoom
        let newZoom = min(max(oldZoom * factor, Self.minimumZoom), Self.maximumZoom)
        let document = documentPoint(from: anchor, zoom: oldZoom, pan: pan)
        assignZoom(newZoom)
        pan = CGPoint(x: anchor.x - document.x * newZoom, y: anchor.y - document.y * newZoom)
    }

    /// Fits a view-space rectangle, such as a zoom-tool marquee, into the visible canvas.
    func zoom(toViewRect rect: CGRect) {
        let box = rect.standardized
        guard box.width > 4, box.height > 4 else { return }
        let topLeft = documentPoint(from: CGPoint(x: box.minX, y: box.minY))
        let bottomRight = documentPoint(from: CGPoint(x: box.maxX, y: box.maxY))
        let documentRect = CGRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y)
        )
        guard documentRect.width > 0.5, documentRect.height > 0.5 else { return }
        let available = contentBounds.insetBy(dx: 12, dy: 12)
        guard available.width > 8, available.height > 8 else { return }
        let scale = min(available.width / documentRect.width, available.height / documentRect.height)
        assignZoom(min(max(scale, Self.minimumZoom), Self.maximumZoom))
        pan = CGPoint(
            x: available.midX - documentRect.midX * zoom,
            y: available.midY - documentRect.midY * zoom
        )
    }

    private func assignZoom(_ value: CGFloat) {
        zoom = value
        tools.interactionZoom = value
    }

    private func documentPoint(from viewPoint: CGPoint, zoom: CGFloat, pan: CGPoint) -> CGPoint {
        CGPoint(x: (viewPoint.x - pan.x) / zoom, y: (viewPoint.y - pan.y) / zoom)
    }

    private func updateComposite(model: DocumentModel, full: Bool, rect: CGRect) {
        let sizeChanged = compositeContext == nil
            || compositeContext?.width != model.width
            || compositeContext?.height != model.height
        if sizeChanged {
            layerCache.invalidate()
            compositeContext = Compositor.makeContext(width: model.width, height: model.height)
            if let compositeContext {
                Compositor.draw(model, into: compositeContext, documentClip: nil, cache: layerCache)
            }
            noteMetal(full: true, rect: .null)
        } else if let compositeContext {
            let clip = tileClip(full: full, rect: rect, model: model)
            if clip == nil {
                layerCache.invalidate()
            }
            Compositor.draw(model, into: compositeContext, documentClip: clip, cache: layerCache)
        }
        compositeImage = compositeContext?.makeImage()
    }

    private var contentBounds: CGRect {
        CGRect(
            x: bounds.minX + rulerInset,
            y: bounds.minY + rulerInset,
            width: max(0, bounds.width - rulerInset),
            height: max(0, bounds.height - rulerInset)
        )
    }

    private func needsCompositeRefresh() -> Bool {
        let model = document.canvasModel()
        return compositeImage == nil
            || compositeContext?.width != model.width
            || compositeContext?.height != model.height
            || appliedRenderGeneration != document.renderGeneration
            || appliedCompositeToken != compositeToken
    }

    private func tileClip(full: Bool, rect: CGRect, model: DocumentModel) -> CGRect? {
        if full || rect.isNull || rect.isEmpty {
            noteMetal(full: true, rect: .null)
            return nil
        }
        let tiles = CanvasTiles.rects(covering: rect, canvasWidth: model.width, canvasHeight: model.height)
        guard let clip = CanvasTiles.union(tiles) else {
            noteMetal(full: true, rect: .null)
            return nil
        }
        noteMetal(full: false, rect: clip)
        return clip
    }

    private func noteMetal(full: Bool, rect: CGRect) {
        if full {
            pendingMetalFull = true
            pendingMetalRect = .null
        } else if !pendingMetalFull {
            pendingMetalRect = pendingMetalRect.isNull ? rect : pendingMetalRect.union(rect)
        }
    }

    func withCompositeBuffer(_ body: (UnsafePointer<UInt8>, Int, Int, Int, [CGRect]) -> Void) {
        guard let compositeContext, let data = compositeContext.data else { return }
        let width = compositeContext.width
        let height = compositeContext.height
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        let tiles = pendingMetalFull
            ? CanvasTiles.rects(covering: canvas, canvasWidth: width, canvasHeight: height)
            : CanvasTiles.rects(covering: pendingMetalRect, canvasWidth: width, canvasHeight: height)
        pendingMetalFull = false
        pendingMetalRect = .null
        body(data.assumingMemoryBound(to: UInt8.self), width, height, compositeContext.bytesPerRow, tiles)
    }
}

struct PointerModifiers: Equatable, Sendable {
    var shift = false
    var option = false
    var command = false
}

struct TransformSession: Equatable {
    var layerID: UUID
    var source: PixelBuffer
    var placement: LayerPlacement
    var corners: [CGPoint]?
    var distorting: Bool
}

struct BakedLayer: Equatable {
    var id: UUID
    var buffer: PixelBuffer
    var originX: Int
    var originY: Int
}

private struct GuideDraft: Equatable {
    var id: UUID
    var axis: CanvasGuide.Axis
    var position: Double
    var isNew: Bool
}

private struct TransformDrag {
    var start: CGPoint
    var placement: LayerPlacement
    var corners: [CGPoint]?
    var resizeIndex: Int?
    var rotating: Bool
    var moving: Bool
}

extension CanvasViewModel {
    func setShowsRulers(_ shown: Bool) {
        guard showsRulers != shown else { return }
        let before = rulerInset
        showsRulers = shown
        let delta = rulerInset - before
        pan.x += delta
        pan.y += delta
        displayGeneration += 1
    }

    func setShowsGuides(_ shown: Bool) {
        showsGuides = shown
        displayGeneration += 1
    }

    func setShowsGrid(_ shown: Bool) {
        showsGrid = shown
        displayGeneration += 1
    }

    func setSnapEnabled(_ enabled: Bool) {
        snapEnabled = enabled
    }

    func setGrid(spacing: Int, subdivisions: Int) {
        grid = LayoutGrid(spacing: spacing, subdivisions: subdivisions)
        displayGeneration += 1
    }

    func pan(from anchorView: CGPoint, anchorPan: CGPoint, to viewPoint: CGPoint) {
        pan = CGPoint(x: anchorPan.x + viewPoint.x - anchorView.x, y: anchorPan.y + viewPoint.y - anchorView.y)
    }

    func rulerAxis(at viewPoint: CGPoint) -> CanvasGuide.Axis? {
        guard showsRulers else { return nil }
        if viewPoint.y < rulerInset, viewPoint.x >= rulerInset { return .horizontal }
        if viewPoint.x < rulerInset, viewPoint.y >= rulerInset { return .vertical }
        return nil
    }

    func beginGuide(at viewPoint: CGPoint, allowsExisting: Bool) -> Bool {
        if let axis = rulerAxis(at: viewPoint) {
            showsGuides = true
            guideDraft = GuideDraft(
                id: UUID(),
                axis: axis,
                position: snapped(documentPosition(axis, at: viewPoint), axis: axis, excluding: nil),
                isNew: true
            )
            displayGeneration += 1
            return true
        }
        guard allowsExisting, showsGuides, transform == nil else { return false }
        guard let guide = GuideHit.nearest(guides: document.model.guides, viewPoint: viewPoint, zoom: zoom, pan: pan) else {
            return false
        }
        guideDraft = GuideDraft(id: guide.id, axis: guide.axis, position: guide.position, isNew: false)
        displayGeneration += 1
        return true
    }

    func updateGuide(to viewPoint: CGPoint) {
        guard var draft = guideDraft else { return }
        draft.position = snapped(documentPosition(draft.axis, at: viewPoint), axis: draft.axis, excluding: draft.id)
        guideDraft = draft
        displayGeneration += 1
    }

    func finishGuide(at viewPoint: CGPoint) {
        guard let draft = guideDraft else { return }
        let delete = rulerAxis(at: viewPoint) != nil
        guideDraft = nil
        if delete {
            if !draft.isNew {
                document.edit(redraw: .none) { model in
                    model.guides.removeAll { $0.id == draft.id }
                }
            }
        } else if draft.isNew {
            document.edit(redraw: .none) { model in
                model.guides.append(CanvasGuide(id: draft.id, axis: draft.axis, position: draft.position))
            }
        } else {
            document.edit(redraw: .none) { model in
                guard let index = model.guides.firstIndex(where: { $0.id == draft.id }) else { return }
                model.guides[index].position = draft.position
            }
        }
        displayGeneration += 1
    }

    func clearGuides() {
        guard !document.model.guides.isEmpty else { return }
        document.edit(redraw: .none) { $0.guides = [] }
        displayGeneration += 1
    }

    func addGuide(axis: CanvasGuide.Axis) {
        let position = axis == .vertical ? Double(document.model.width) / 2 : Double(document.model.height) / 2
        showsGuides = true
        document.edit(redraw: .none) { model in
            model.guides.append(CanvasGuide(id: UUID(), axis: axis, position: position))
        }
        displayGeneration += 1
    }

    func beginTransform(layer: PixelLayer, distort: Bool) {
        let placement = LayerPlacement(
            origin: CGPoint(x: layer.originX, y: layer.originY),
            size: CGSize(width: layer.buffer.width, height: layer.buffer.height)
        )
        transform = TransformSession(
            layerID: layer.id,
            source: layer.buffer,
            placement: placement,
            corners: distort ? placement.corners() : nil,
            distorting: distort
        )
        transformImage = layer.buffer.cgImage()
        transformDrag = nil
        compositeToken += 1
        displayGeneration += 1
    }

    func clearTransform() {
        guard transform != nil else { return }
        transform = nil
        transformDrag = nil
        transformImage = nil
        compositeToken += 1
        displayGeneration += 1
    }

    @discardableResult
    func flipDraft(horizontally: Bool) -> Bool {
        guard var session = transform else { return false }
        if horizontally { session.placement.flipX.toggle() } else { session.placement.flipY.toggle() }
        transform = session
        displayGeneration += 1
        return true
    }

    func bakedTransform() -> BakedLayer? {
        guard let session = transform else { return nil }
        let baked: (buffer: PixelBuffer, originX: Int, originY: Int)?
        if session.distorting, let corners = session.corners {
            baked = PixelWarp.warp(source: session.source, corners: corners, sampling: session.placement.sampling)
        } else {
            baked = PixelRasterizer.bake(source: session.source, placement: session.placement)
        }
        guard let baked else { return nil }
        return BakedLayer(id: session.layerID, buffer: baked.buffer, originX: baked.originX, originY: baked.originY)
    }

    func beginTransformDrag(at documentPoint: CGPoint, viewPoint: CGPoint, modifiers: PointerModifiers) -> Bool {
        guard var session = transform else { return false }
        if session.distorting, let corners = session.corners {
            if let index = nearestCorner(corners, to: viewPoint) {
                transformDrag = TransformDrag(start: documentPoint, placement: session.placement, corners: corners, resizeIndex: index, rotating: false, moving: false)
                return true
            }
            if quadContains(corners, documentPoint) {
                transformDrag = TransformDrag(start: documentPoint, placement: session.placement, corners: corners, resizeIndex: nil, rotating: false, moving: true)
                return true
            }
            return false
        }
        if modifiers.command, let index = nearestHandle(session.placement, to: viewPoint) {
            session.distorting = true
            session.corners = session.placement.corners()
            transform = session
            let corner = PlacementDrag.movedCorners(handle: index)[0]
            transformDrag = TransformDrag(start: documentPoint, placement: session.placement, corners: session.corners, resizeIndex: corner, rotating: false, moving: false)
            displayGeneration += 1
            return true
        }
        if let index = nearestHandle(session.placement, to: viewPoint) {
            transformDrag = TransformDrag(start: documentPoint, placement: session.placement, corners: nil, resizeIndex: index, rotating: false, moving: false)
            return true
        }
        let top = self.viewPoint(from: session.placement.point(CGPoint(x: 0.5, y: 0)))
        if hypot(viewPoint.x - top.x, viewPoint.y - (top.y - 24)) <= 10 {
            transformDrag = TransformDrag(start: documentPoint, placement: session.placement, corners: nil, resizeIndex: nil, rotating: true, moving: false)
            return true
        }
        if session.placement.contains(documentPoint) {
            transformDrag = TransformDrag(start: documentPoint, placement: session.placement, corners: nil, resizeIndex: nil, rotating: false, moving: true)
            return true
        }
        return false
    }

    func updateTransformDrag(to documentPoint: CGPoint, modifiers: PointerModifiers) {
        guard let drag = transformDrag, var session = transform else { return }
        if session.distorting, var corners = drag.corners {
            if drag.moving {
                let dx = documentPoint.x - drag.start.x
                let dy = documentPoint.y - drag.start.y
                corners = corners.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            } else if let index = drag.resizeIndex {
                corners = PlacementDrag.draggedCorners(corners, indices: [index], from: drag.start, to: documentPoint, shift: modifiers.shift)
            }
            session.corners = corners
            transform = session
            displayGeneration += 1
            return
        }
        let mode: PlacementDrag.Mode
        if drag.rotating {
            mode = .rotate
        } else if drag.moving {
            mode = .move
        } else if let index = drag.resizeIndex {
            mode = .resize(index)
        } else {
            return
        }
        session.placement = PlacementDrag.updated(
            original: drag.placement,
            mode: mode,
            start: drag.start,
            point: documentPoint,
            lockRatio: false,
            shift: modifiers.shift,
            option: modifiers.option
        )
        transform = session
        displayGeneration += 1
    }

    func endTransformDrag() {
        transformDrag = nil
    }

    private func documentPosition(_ axis: CanvasGuide.Axis, at viewPoint: CGPoint) -> Double {
        if axis == .vertical {
            return Double((viewPoint.x - pan.x) / zoom)
        }
        return Double((viewPoint.y - pan.y) / zoom)
    }

    private func snapped(_ position: Double, axis: CanvasGuide.Axis, excluding: UUID?) -> Double {
        guard snapEnabled else { return position }
        let length = CGFloat(axis == .vertical ? document.model.width : document.model.height)
        let tolerance = 10 / max(zoom, 0.0001)
        let value = CGFloat(position)
        var targets: [CGFloat] = [0, length / 2, length]
        if let gridLine = grid.snap(value, tolerance: tolerance, visible: showsGrid) {
            targets.append(gridLine)
        }
        if showsGuides {
            targets += document.model.guides.filter { $0.axis == axis && $0.id != excluding }.map { CGFloat($0.position) }
        }
        var best: CGFloat?
        for target in targets where abs(target - value) <= tolerance {
            if let current = best, abs(current - value) <= abs(target - value) { continue }
            best = target
        }
        return Double(best ?? value)
    }

    private func nearestHandle(_ placement: LayerPlacement, to viewPoint: CGPoint) -> Int? {
        for (index, unit) in LayerPlacement.handles.enumerated() {
            let point = self.viewPoint(from: placement.point(unit))
            if hypot(viewPoint.x - point.x, viewPoint.y - point.y) <= 8 { return index }
        }
        return nil
    }

    private func nearestCorner(_ corners: [CGPoint], to viewPoint: CGPoint) -> Int? {
        for (index, corner) in corners.enumerated() {
            let point = self.viewPoint(from: corner)
            if hypot(viewPoint.x - point.x, viewPoint.y - point.y) <= 8 { return index }
        }
        return nil
    }

    private func quadContains(_ corners: [CGPoint], _ point: CGPoint) -> Bool {
        guard corners.count == 4 else { return false }
        var winding = false
        for index in 0..<4 {
            let a = corners[index]
            let b = corners[(index + 1) % 4]
            if (a.y > point.y) != (b.y > point.y),
               point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
                winding.toggle()
            }
        }
        return winding
    }
}

