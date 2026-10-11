// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import MetalKit

@MainActor
final class CanvasView: NSView {
    var model: CanvasViewModel? {
        didSet { needsDisplay = true }
    }

    private var brushCursorPoint: CGPoint?
    private var checkerboard: NSColor?
    private var tracking: NSTrackingArea?
    private var metalView: PassThroughMTKView?
    private var overlayView: CanvasOverlayView?
    private var spaceDown = false
    private var drag: DragKind?

    fileprivate enum DragKind {
        case tool
        case pan(anchorView: CGPoint, anchorPan: CGPoint)
        case zoom(anchor: CGPoint, current: CGPoint, moved: Bool)
        case guide
        case transform
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        tracking = area
        addTrackingArea(area)
    }

    override func resetCursorRects() {
        let cursor: NSCursor
        if drag?.isPan == true || spaceDown {
            cursor = .closedHand
        } else {
            switch model?.tools.tool {
            case .hand:
                cursor = .openHand
            case .move, nil:
                cursor = .arrow
            default:
                cursor = .crosshair
            }
        }
        addCursorRect(bounds, cursor: cursor)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        checkerboard = nil
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        metalView?.frame = bounds
        overlayView?.frame = bounds
        if model?.layout(bounds: bounds) == true {
            needsDisplay = true
        }
    }

    override func setNeedsDisplay(_ invalidRect: NSRect) {
        super.setNeedsDisplay(invalidRect)
        overlayView?.needsDisplay = true
        metalView?.needsDisplay = true
    }

    func syncFromModel() {
        guard let model else { return }
        installMetalIfAvailable()
        model.sync(bounds: bounds)
        if model.tools.tool.usesRoundCursor == false {
            brushCursorPoint = nil
        }
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        if metalView != nil { return }
        drawScene(dirtyRect)
    }

    func drawOverlays(_ dirtyRect: NSRect) {
        drawChrome(dirtyRect)
    }

    override func mouseDown(with event: NSEvent) {
        if model?.tools.tool != .type {
            window?.makeFirstResponder(self)
        }
        guard let model else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)
        let documentPoint = model.documentPoint(from: viewPoint)
        let modifiers = PointerModifiers(event)
        if model.beginGuide(at: viewPoint, allowsExisting: model.tools.tool == .move) {
            drag = .guide
            needsDisplay = true
            return
        }
        if model.beginTransformDrag(at: documentPoint, viewPoint: viewPoint, modifiers: modifiers) {
            drag = .transform
            needsDisplay = true
            return
        }
        if spaceDown || model.tools.tool == .hand {
            drag = .pan(anchorView: viewPoint, anchorPan: model.pan)
            window?.invalidateCursorRects(for: self)
            return
        }
        if model.tools.tool == .zoom {
            drag = .zoom(anchor: viewPoint, current: viewPoint, moved: false)
            return
        }
        drag = .tool
        let shift = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)
        model.tools.mouseDown(at: documentPoint, shift: shift, option: option, clickCount: event.clickCount)
        if model.tools.tool.usesRoundCursor {
            setBrushCursor(documentPoint)
        }
        if model.tools.tool.paintsContinuously {
            apply(model.refreshPixels(allowEmpty: false))
        } else {
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let model else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)
        let documentPoint = model.documentPoint(from: viewPoint)
        let modifiers = PointerModifiers(event)
        switch drag {
        case .guide:
            model.updateGuide(to: viewPoint)
            needsDisplay = true
        case .transform:
            model.updateTransformDrag(to: documentPoint, modifiers: modifiers)
            needsDisplay = true
        case .pan(let anchorView, let anchorPan):
            model.pan(from: anchorView, anchorPan: anchorPan, to: viewPoint)
            needsDisplay = true
        case .zoom(let anchor, _, let wasMoved):
            let moved = wasMoved || hypot(viewPoint.x - anchor.x, viewPoint.y - anchor.y) > 3
            drag = .zoom(anchor: anchor, current: viewPoint, moved: moved)
            needsDisplay = true
        case .tool, nil:
            let shift = event.modifierFlags.contains(.shift)
            let option = event.modifierFlags.contains(.option)
            if model.tools.tool.usesRoundCursor {
                setBrushCursor(documentPoint)
            }
            model.tools.mouseDragged(to: documentPoint, shift: shift, option: option)
            if model.tools.tool.paintsContinuously {
                apply(model.refreshPixels(allowEmpty: false))
            } else {
                needsDisplay = true
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let model else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)
        let documentPoint = model.documentPoint(from: viewPoint)
        let modifiers = PointerModifiers(event)
        let kind = drag
        drag = nil
        switch kind {
        case .guide:
            model.finishGuide(at: viewPoint)
            needsDisplay = true
        case .transform:
            model.endTransformDrag()
            needsDisplay = true
        case .pan:
            window?.invalidateCursorRects(for: self)
        case .zoom(let anchor, let current, let moved):
            if moved {
                let rect = CGRect(
                    x: min(anchor.x, current.x),
                    y: min(anchor.y, current.y),
                    width: abs(current.x - anchor.x),
                    height: abs(current.y - anchor.y)
                )
                model.zoom(toViewRect: rect)
            } else {
                model.zoom(by: modifiers.option ? 0.5 : 2, anchor: anchor)
            }
            needsDisplay = true
        case .tool, nil:
            let shift = modifiers.shift
            let option = modifiers.option
            let painting = model.tools.tool.paintsContinuously
            model.tools.mouseUp(at: documentPoint, shift: shift, option: option)
            if painting {
                apply(model.refreshPixels(allowEmpty: false))
            } else {
                needsDisplay = true
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard let model else { return }
        let point = model.documentPoint(from: convert(event.locationInWindow, from: nil))
        if model.tools.tool.usesRoundCursor || model.tools.tool == .lasso || model.tools.tool == .clone {
            if model.tools.tool.usesRoundCursor {
                setBrushCursor(point)
            }
            model.tools.hover(at: point)
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        setBrushCursor(nil)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let model else { return }
        let anchor = convert(event.locationInWindow, from: nil)
        model.scroll(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            precise: event.hasPreciseScrollingDeltas,
            inverted: event.isDirectionInvertedFromDevice,
            commandPressed: event.modifierFlags.contains(.command),
            anchor: anchor,
            bounds: bounds
        )
        needsDisplay = true
    }

    override func magnify(with event: NSEvent) {
        guard let model else { return }
        let anchor = convert(event.locationInWindow, from: nil)
        model.magnify(by: event.magnification, anchor: anchor)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let plain = event.modifierFlags.intersection([.command, .option, .control]).isEmpty
        if model?.tools.isEditingText == true {
            if event.keyCode == 53, plain {
                model?.tools.endTextEditing()
                needsDisplay = true
            } else if event.keyCode == 36 || event.keyCode == 76 {
                model?.tools.commitType()
                needsDisplay = true
            } else {
                model?.tools.focusTypeEditor()
            }
            return
        }
        if event.keyCode == 49 {
            spaceDown = true
            window?.invalidateCursorRects(for: self)
            return
        }
        if model?.isTransforming == true, event.keyCode == 53 {
            model?.clearTransform()
            needsDisplay = true
            return
        }
        if model?.isTransforming == true, event.keyCode == 36 || event.keyCode == 76 {
            NotificationCenter.default.post(name: .ptuApplyTransform, object: nil)
            return
        }
        if model?.tools.tool == .crop, event.keyCode == 53 {
            model?.tools.cancelCrop()
            return
        }
        if model?.tools.tool == .crop, event.keyCode == 36 || event.keyCode == 76 {
            model?.tools.applyCrop()
            return
        }
        if model?.tools.handleKey(
            characters: event.charactersIgnoringModifiers ?? "",
            keyCode: event.keyCode,
            command: event.modifierFlags.contains(.command)
        ) == true {
            needsDisplay = true
            if model?.tools.tool.paintsContinuously == false {
                _ = model?.refreshPixels(allowEmpty: true)
            }
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            model?.tools.deleteSelection()
            return
        }
        if plain, let tool = TextEditingGate.shelfTool(
            for: event.charactersIgnoringModifiers ?? "",
            isEditingText: model?.tools.isEditingText == true
        ) {
            model?.tools.tool = tool
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceDown = false
            window?.invalidateCursorRects(for: self)
            return
        }
        super.keyUp(with: event)
    }

    private func installMetalIfAvailable() {
        guard metalView == nil, let display = MetalCanvasDisplay.shared else { return }
        let metal = PassThroughMTKView(frame: bounds, device: display.device)
        metal.colorPixelFormat = .bgra8Unorm
        metal.framebufferOnly = false
        metal.isPaused = true
        metal.enableSetNeedsDisplay = true
        metal.delegate = display
        metal.autoresizingMask = [.width, .height]
        display.onDraw = { [weak self] view in
            self?.renderMetal(view)
        }
        let overlay = CanvasOverlayView(frame: bounds)
        overlay.canvas = self
        addSubview(metal)
        addSubview(overlay)
        metalView = metal
        overlayView = overlay
    }

    private func renderMetal(_ view: MTKView) {
        guard let model else { return }
        let light = SIMD4<Float>.srgb(.controlBackgroundColor)
        let dark = SIMD4<Float>.srgb(.windowBackgroundColor)
        let backdrop = SIMD4<Float>.srgb(.underPageBackgroundColor)
        model.withCompositeBuffer { bytes, width, height, rowBytes, tiles in
            MetalCanvasDisplay.shared?.render(
                bytes: bytes,
                width: width,
                height: height,
                bytesPerRow: rowBytes,
                dirtyTiles: tiles,
                pan: model.pan,
                zoom: model.zoom,
                viewSize: view.bounds.size,
                checkerLight: light,
                checkerDark: dark,
                backdrop: backdrop,
                in: view
            )
        }
    }

    private func drawScene(_ dirtyRect: NSRect) {
        guard let model else { return }
        NSColor.underPageBackgroundColor.setFill()
        dirtyRect.fill()
        let documentRect = documentViewRect(model)
        drawCheckerboard(in: documentRect)
        if let compositeImage = model.compositeImage {
            drawComposite(compositeImage, in: documentRect)
        }
        drawChrome(dirtyRect)
    }

    private func documentViewRect(_ model: CanvasViewModel) -> NSRect {
        NSRect(
            x: model.pan.x,
            y: model.pan.y,
            width: model.contentWidth * model.zoom,
            height: model.contentHeight * model.zoom
        )
    }

    private func drawChrome(_ dirtyRect: NSRect) {
        guard let model else { return }
        let documentRect = documentViewRect(model)
        if model.showsGrid {
            drawGrid(model, in: documentRect)
        }
        if model.showsGuides {
            drawGuides(model)
        }
        if let selection = model.tools.selection, !selection.isEmpty, selection.bounds.width > 0, selection.bounds.height > 0 {
            drawPixelSelection(selection)
        }
        if let draft = model.tools.selectionDraft {
            drawPixelSelection(draft)
        }
        drawMarkupOverlays(model)
        if model.tools.tool == .crop, let crop = model.tools.cropRect, crop.width > 0, crop.height > 0 {
            drawCrop(crop, within: documentRect)
        }
        if model.tools.tool.usesRoundCursor, let hover = brushCursorPoint {
            let radius = CGFloat(model.tools.brushSize) / 2 * model.zoom
            let center = model.viewPoint(from: hover)
            let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            NSColor.secondaryLabelColor.setStroke()
            NSBezierPath(ovalIn: rect).stroke()
        }
        if let session = model.transform {
            drawTransform(session, model: model)
        }
        if case .zoom(let anchor, let current, true) = drag {
            drawZoomMarquee(from: anchor, to: current)
        }
        if model.showsRulers {
            drawRulers(model)
        }
        _ = dirtyRect
    }

    private func drawZoomMarquee(from anchor: CGPoint, to current: CGPoint) {
        let rect = NSRect(
            x: min(anchor.x, current.x),
            y: min(anchor.y, current.y),
            width: abs(current.x - anchor.x),
            height: abs(current.y - anchor.y)
        )
        NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
        rect.fill()
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1
        path.stroke()
    }

    private func drawPixelSelection(_ selection: PixelSelection) {
        if selection.mask != nil, let image = selection.tintImage(), let model {
            let documentRect = documentViewRect(model)
            NSGraphicsContext.current?.cgContext.setAlpha(0.35)
            drawComposite(image, in: documentRect)
            NSGraphicsContext.current?.cgContext.setAlpha(1)
        }
        for element in selection.geometry.elements {
            switch element {
            case .rect(let rect):
                stroke(rect, color: .controlAccentColor, dashed: true)
            case .ellipse(let rect):
                strokeOval(rect)
            case .polygon(let points):
                strokePolygon(points, closed: true)
            }
        }
        if selection.geometry.elements.isEmpty {
            stroke(selection.bounds, color: .controlAccentColor, dashed: true)
        }
    }

    private func drawMarkupOverlays(_ model: CanvasViewModel) {
        let tools = model.tools
        if tools.lassoDraft.count >= 1 {
            var points = tools.lassoDraft
            if let cursor = tools.lassoCursor { points.append(cursor) }
            strokePolygon(points, closed: false)
        }
        if let shape = tools.shapeDraft {
            let color = model.tools.document.foreground.nsColor.withAlphaComponent(0.85)
            switch shape.kind {
            case .rectangle:
                stroke(shape.rect, color: color, dashed: false)
            case .ellipse:
                strokeOval(shape.rect, color: color)
            case .line:
                strokePolygon([shape.anchor, shape.current], closed: false, color: color)
            }
        }
        if let start = tools.gradientStart, let end = tools.gradientEnd {
            strokePolygon([start, end], closed: false)
        }
        if let floating = tools.floating, let image = floating.pixels.cgImage() {
            let rect = model.viewRect(for: CGRect(x: floating.originX, y: floating.originY, width: floating.pixels.width, height: floating.pixels.height))
            drawComposite(image, in: rect)
        }
        if let origin = tools.typeOrigin, let layout = tools.typePreview, let image = layout.buffer.cgImage() {
            let rect = model.viewRect(for: CGRect(x: origin.x, y: origin.y, width: CGFloat(layout.buffer.width), height: CGFloat(layout.buffer.height)))
            drawComposite(image, in: rect)
            stroke(layout.caret, color: .controlAccentColor, dashed: false)
        }
        if tools.tool == .heal {
            for dab in tools.healDabs {
                let radius = CGFloat(tools.brushSize) / 2
                strokeOval(CGRect(x: dab.x - radius, y: dab.y - radius, width: radius * 2, height: radius * 2), color: .systemOrange)
            }
        }
        if tools.tool == .clone, let hover = tools.hoverPoint, let sample = tools.cloneSamplePoint(for: hover) {
            let center = model.viewPoint(from: sample)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: center.x - 6, y: center.y))
            path.line(to: NSPoint(x: center.x + 6, y: center.y))
            path.move(to: NSPoint(x: center.x, y: center.y - 6))
            path.line(to: NSPoint(x: center.x, y: center.y + 6))
            NSColor.systemOrange.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func strokeOval(_ documentRect: CGRect, color: NSColor = .controlAccentColor) {
        guard let model else { return }
        let rect = model.viewRect(for: documentRect)
        let path = NSBezierPath(ovalIn: rect)
        path.setLineDash([4, 3], count: 2, phase: 0)
        color.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func strokePolygon(_ points: [CGPoint], closed: Bool, color: NSColor = .controlAccentColor) {
        guard let model, points.count >= 2 else { return }
        let path = NSBezierPath()
        path.move(to: model.viewPoint(from: points[0]))
        for point in points.dropFirst() {
            path.line(to: model.viewPoint(from: point))
        }
        if closed { path.close() }
        path.setLineDash([4, 3], count: 2, phase: 0)
        color.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func apply(_ dirty: CanvasDisplayDirty) {
        switch dirty {
        case .none:
            break
        case .full:
            needsDisplay = true
        case .rect(let rect):
            setNeedsDisplay(rect)
        }
    }

    private func drawComposite(_ image: CGImage, in documentRect: NSRect) {
        guard let model, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.interpolationQuality = model.zoom == 1 ? .none : .medium
        context.translateBy(x: documentRect.minX, y: documentRect.minY + documentRect.height)
        context.scaleBy(
            x: documentRect.width / CGFloat(image.width),
            y: -documentRect.height / CGFloat(image.height)
        )
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.restoreGState()
    }

    private func setBrushCursor(_ point: CGPoint?) {
        let previous = brushCursorPoint
        brushCursorPoint = point
        if let previous {
            setNeedsDisplay(brushCursorRect(at: previous))
        }
        if let point {
            setNeedsDisplay(brushCursorRect(at: point))
        }
    }

    private func brushCursorRect(at documentPoint: CGPoint) -> NSRect {
        guard let model else { return .zero }
        let radius = CGFloat(model.tools.brushSize) / 2 * model.zoom + 2
        let center = model.viewPoint(from: documentPoint)
        return NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    private func drawCheckerboard(in rect: NSRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.clip(to: rect)
        context.setPatternPhase(CGSize(width: rect.minX, height: rect.minY))
        checkerColor().setFill()
        rect.fill()
        context.restoreGState()
    }

    private func checkerColor() -> NSColor {
        if let checkerboard { return checkerboard }
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.controlBackgroundColor.setFill()
        NSRect(x: 0, y: 0, width: 16, height: 16).fill()
        NSColor.windowBackgroundColor.setFill()
        NSRect(x: 8, y: 0, width: 8, height: 8).fill()
        NSRect(x: 0, y: 8, width: 8, height: 8).fill()
        image.unlockFocus()
        let color = NSColor(patternImage: image)
        checkerboard = color
        return color
    }

    private func stroke(_ documentRect: CGRect, color: NSColor, dashed: Bool) {
        guard let model else { return }
        let rect = model.viewRect(for: documentRect)
        let path = NSBezierPath(rect: rect)
        if dashed {
            path.setLineDash([4, 3], count: 2, phase: 0)
        }
        color.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawCrop(_ documentRect: CGRect, within documentBounds: NSRect) {
        dimOutside(documentRect, within: documentBounds)
        stroke(documentRect, color: .controlAccentColor, dashed: false)
        guard let model else { return }
        let rect = model.viewRect(for: documentRect)
        let thirds = NSBezierPath()
        for index in 1...2 {
            let fraction = CGFloat(index) / 3
            thirds.move(to: NSPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
            thirds.line(to: NSPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
            thirds.move(to: NSPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
            thirds.line(to: NSPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
        }
        NSColor.controlAccentColor.withAlphaComponent(0.45).setStroke()
        thirds.lineWidth = 1
        thirds.stroke()
        NSColor.controlBackgroundColor.setFill()
        NSColor.controlAccentColor.setStroke()
        for point in cropHandles(in: rect) {
            let handle = NSRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            NSBezierPath(rect: handle).fill()
            NSBezierPath(rect: handle).stroke()
        }
    }

    private func cropHandles(in rect: NSRect) -> [NSPoint] {
        [
            NSPoint(x: rect.minX, y: rect.minY),
            NSPoint(x: rect.midX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.midY),
            NSPoint(x: rect.maxX, y: rect.maxY),
            NSPoint(x: rect.midX, y: rect.maxY),
            NSPoint(x: rect.minX, y: rect.maxY),
            NSPoint(x: rect.minX, y: rect.midY),
        ]
    }

    private func dimOutside(_ documentRect: CGRect, within documentBounds: NSRect) {
        guard let model else { return }
        let hole = model.viewRect(for: documentRect)
        NSColor.windowBackgroundColor.withAlphaComponent(0.55).setFill()
        let boundsPath = NSBezierPath(rect: documentBounds)
        boundsPath.append(NSBezierPath(rect: hole))
        boundsPath.windingRule = .evenOdd
        boundsPath.fill()
    }

    private func drawGuides(_ model: CanvasViewModel) {
        NSColor.cyan.withAlphaComponent(0.9).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        for guide in model.displayedGuides {
            if guide.axis == .vertical {
                let x = model.pan.x + CGFloat(guide.position) * model.zoom
                path.move(to: NSPoint(x: x, y: model.rulerInset))
                path.line(to: NSPoint(x: x, y: bounds.maxY))
            } else {
                let y = model.pan.y + CGFloat(guide.position) * model.zoom
                path.move(to: NSPoint(x: model.rulerInset, y: y))
                path.line(to: NSPoint(x: bounds.maxX, y: y))
            }
        }
        path.stroke()
    }

    private func drawGrid(_ model: CanvasViewModel, in documentRect: NSRect) {
        let vertical = model.grid.lines(along: model.contentWidth)
        let horizontal = model.grid.lines(along: model.contentHeight)
        let minor = NSBezierPath()
        let major = NSBezierPath()
        for value in vertical {
            let x = model.pan.x + value * model.zoom
            let path = model.grid.isMajor(value) ? major : minor
            path.move(to: NSPoint(x: x, y: documentRect.minY))
            path.line(to: NSPoint(x: x, y: documentRect.maxY))
        }
        for value in horizontal {
            let y = model.pan.y + value * model.zoom
            let path = model.grid.isMajor(value) ? major : minor
            path.move(to: NSPoint(x: documentRect.minX, y: y))
            path.line(to: NSPoint(x: documentRect.maxX, y: y))
        }
        NSColor.secondaryLabelColor.withAlphaComponent(0.28).setStroke()
        minor.lineWidth = 1
        minor.setLineDash([1, 2], count: 2, phase: 0)
        minor.stroke()
        NSColor.secondaryLabelColor.withAlphaComponent(0.45).setStroke()
        major.lineWidth = 1
        major.stroke()
    }

    private func drawTransform(_ session: TransformSession, model: CanvasViewModel) {
        let corners = session.distorting ? (session.corners ?? session.placement.corners()) : session.placement.corners()
        if !session.distorting, let image = model.transformImage, let context = NSGraphicsContext.current?.cgContext {
            let placement = session.placement
            let center = model.viewPoint(from: placement.center)
            let width = placement.size.width * model.zoom
            let height = placement.size.height * model.zoom
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: placement.radians)
            context.scaleBy(x: placement.flipX ? -1 : 1, y: placement.flipY ? -1 : 1)
            context.translateBy(x: -width / 2, y: -height / 2)
            context.translateBy(x: 0, y: height)
            context.scaleBy(x: width / CGFloat(image.width), y: -height / CGFloat(image.height))
            context.interpolationQuality = model.zoom == 1 ? .none : .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.restoreGState()
        }
        let path = NSBezierPath()
        let viewCorners = corners.map { model.viewPoint(from: $0) }
        if let first = viewCorners.first {
            path.move(to: first)
            for point in viewCorners.dropFirst() { path.line(to: point) }
            path.close()
        }
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        NSColor.controlBackgroundColor.setFill()
        for point in viewCorners {
            let handle = NSRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            NSBezierPath(ovalIn: handle).fill()
            NSBezierPath(ovalIn: handle).stroke()
        }
        if !session.distorting, let top = viewCorners.first.map({ _ in model.viewPoint(from: session.placement.point(CGPoint(x: 0.5, y: 0))) }) {
            let knob = NSPoint(x: top.x, y: top.y - 24)
            let stem = NSBezierPath()
            stem.move(to: top)
            stem.line(to: knob)
            stem.stroke()
            NSBezierPath(ovalIn: NSRect(x: knob.x - 5, y: knob.y - 5, width: 10, height: 10)).stroke()
        }
    }

    private func drawRulers(_ model: CanvasViewModel) {
        let thickness = model.rulerInset
        NSColor(white: 0.2, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: thickness).fill()
        NSRect(x: 0, y: 0, width: thickness, height: bounds.height).fill()
        let step = CanvasRulerMetrics.majorStep(pointsPerPixel: model.zoom)
        let minor = step / 10
        guard minor > 0 else { return }
        let tick = NSColor(white: 0.62, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: NSColor(white: 0.78, alpha: 1),
        ]
        drawRulerTicks(model, axis: .horizontal, step: step, minor: minor, thickness: thickness, tick: tick, attributes: attributes)
        drawRulerTicks(model, axis: .vertical, step: step, minor: minor, thickness: thickness, tick: tick, attributes: attributes)
    }

    private func drawRulerTicks(
        _ model: CanvasViewModel,
        axis: CanvasGuide.Axis,
        step: CGFloat,
        minor: CGFloat,
        thickness: CGFloat,
        tick: NSColor,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let start = axis == .horizontal
            ? model.documentPoint(from: CGPoint(x: thickness, y: 0)).x
            : model.documentPoint(from: CGPoint(x: 0, y: thickness)).y
        let end = axis == .horizontal
            ? model.documentPoint(from: CGPoint(x: bounds.width, y: 0)).x
            : model.documentPoint(from: CGPoint(x: 0, y: bounds.height)).y
        var value = floor(min(start, end) / minor) * minor
        let last = ceil(max(start, end) / minor) * minor
        while value <= last + 0.001 {
            let view = axis == .horizontal
                ? model.viewPoint(from: CGPoint(x: value, y: 0)).x
                : model.viewPoint(from: CGPoint(x: 0, y: value)).y
            let remainder = abs(value.remainder(dividingBy: step))
            let isMajor = remainder < 0.001 || abs(remainder - step) < 0.001
            let length: CGFloat = isMajor ? 8 : 3
            tick.setFill()
            if axis == .horizontal {
                NSRect(x: view, y: thickness - length, width: 1, height: length).fill()
                if isMajor {
                    (String(Int(value.rounded())) as NSString).draw(at: NSPoint(x: view + 2, y: 1), withAttributes: attributes)
                }
            } else {
                NSRect(x: thickness - length, y: view, width: length, height: 1).fill()
                if isMajor {
                    (String(Int(value.rounded())) as NSString).draw(at: NSPoint(x: 1, y: view + 2), withAttributes: attributes)
                }
            }
            value += minor
        }
    }
}

private extension PointerModifiers {
    init(_ event: NSEvent) {
        self.init(
            shift: event.modifierFlags.contains(.shift),
            option: event.modifierFlags.contains(.option),
            command: event.modifierFlags.contains(.command)
        )
    }
}

private extension CanvasView.DragKind {
    var isPan: Bool {
        if case .pan = self { return true }
        return false
    }
}

extension Notification.Name {
    static let ptuApplyTransform = Notification.Name("ptuApplyTransform")
}

private final class PassThroughMTKView: MTKView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
private final class CanvasOverlayView: NSView {
    weak var canvas: CanvasView?
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        canvas?.drawOverlays(dirtyRect)
    }
}
