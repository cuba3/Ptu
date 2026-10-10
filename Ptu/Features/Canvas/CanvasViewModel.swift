// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
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

    var zoomPercent: Int { Int((zoom * 100).rounded()) }
    var contentWidth: CGFloat { CGFloat(document.model.width) }
    var contentHeight: CGFloat { CGFloat(document.model.height) }

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
            let anchor = CGPoint(x: bounds.midX, y: bounds.midY)
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
        let model = document.canvasModel()
        if compositeImage == nil
            || compositeContext?.width != model.width
            || compositeContext?.height != model.height
            || appliedRenderGeneration != document.renderGeneration {
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
        let model = document.canvasModel()
        if compositeImage == nil
            || compositeContext?.width != model.width
            || compositeContext?.height != model.height
            || appliedRenderGeneration != document.renderGeneration {
            _ = refreshPixels(allowEmpty: true)
            needsDisplay = true
        }
        return needsDisplay
    }

    func refreshPixels(allowEmpty: Bool) -> CanvasDisplayDirty {
        let model = document.canvasModel()
        let dirty = document.consumeDirty()
        let sizeChanged = compositeContext?.width != model.width || compositeContext?.height != model.height
        let full = dirty.full || sizeChanged || compositeContext == nil
        if !full && (dirty.rect.isNull || dirty.rect.isEmpty) {
            if allowEmpty, compositeImage == nil || sizeChanged {
                updateComposite(model: model, full: true, rect: .null)
                appliedRenderGeneration = document.renderGeneration
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
        guard bounds.width > 40, bounds.height > 40 else { return }
        let documentWidth = contentWidth
        let documentHeight = contentHeight
        guard documentWidth > 0, documentHeight > 0 else { return }
        let scale = min((bounds.width - 40) / documentWidth, (bounds.height - 40) / documentHeight)
        assignZoom(min(max(scale, Self.minimumZoom), Self.maximumZoom))
        pan = CGPoint(
            x: (bounds.width - documentWidth * zoom) / 2,
            y: (bounds.height - documentHeight * zoom) / 2
        )
    }

    private func setZoom(_ newZoom: CGFloat, anchor: CGPoint) {
        let factor = newZoom / max(zoom, 0.0001)
        zoom(by: factor, anchor: anchor)
    }

    private func zoom(by factor: CGFloat, anchor: CGPoint) {
        let oldZoom = zoom
        let newZoom = min(max(oldZoom * factor, Self.minimumZoom), Self.maximumZoom)
        let document = documentPoint(from: anchor, zoom: oldZoom, pan: pan)
        assignZoom(newZoom)
        pan = CGPoint(x: anchor.x - document.x * newZoom, y: anchor.y - document.y * newZoom)
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
        } else if let compositeContext {
            let clip: CGRect? = (full || rect.isNull || rect.isEmpty) ? nil : rect
            if clip == nil {
                layerCache.invalidate()
            }
            Compositor.draw(model, into: compositeContext, documentClip: clip, cache: layerCache)
        }
        compositeImage = compositeContext?.makeImage()
    }
}
