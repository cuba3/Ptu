// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit

@MainActor
final class CanvasView: NSView {
    var model: CanvasViewModel? {
        didSet { needsDisplay = true }
    }

    private var brushCursorPoint: CGPoint?
    private var checkerboard: NSColor?
    private var tracking: NSTrackingArea?

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
        switch model?.tools.tool {
        case .move, nil:
            cursor = .arrow
        case .marquee, .brush, .crop, .eyedropper:
            cursor = .crosshair
        }
        addCursorRect(bounds, cursor: cursor)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        checkerboard = nil
        needsDisplay = true
    }

    func syncFromModel() {
        guard let model else { return }
        model.sync(bounds: bounds)
        if model.tools.tool != .brush {
            brushCursorPoint = nil
        }
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func layout() {
        super.layout()
        if model?.layout(bounds: bounds) == true {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let model else { return }
        NSColor.underPageBackgroundColor.setFill()
        dirtyRect.fill()
        let documentRect = NSRect(
            x: model.pan.x,
            y: model.pan.y,
            width: model.contentWidth * model.zoom,
            height: model.contentHeight * model.zoom
        )
        drawCheckerboard(in: documentRect)
        if let compositeImage = model.compositeImage {
            drawComposite(compositeImage, in: documentRect)
        }
        if let selection = model.tools.selection, selection.width > 0, selection.height > 0 {
            stroke(selection, color: .controlAccentColor, dashed: true)
        }
        if model.tools.tool == .crop, let crop = model.tools.cropRect, crop.width > 0, crop.height > 0 {
            drawCrop(crop, within: documentRect)
        }
        if model.tools.tool == .brush, let hover = brushCursorPoint {
            let radius = CGFloat(model.tools.brushSize) / 2 * model.zoom
            let center = model.viewPoint(from: hover)
            let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            NSColor.secondaryLabelColor.setStroke()
            NSBezierPath(ovalIn: rect).stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let model else { return }
        let point = model.documentPoint(from: convert(event.locationInWindow, from: nil))
        model.tools.mouseDown(at: point)
        if model.tools.tool == .brush {
            setBrushCursor(point)
            apply(model.refreshPixels(allowEmpty: false))
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let model else { return }
        let point = model.documentPoint(from: convert(event.locationInWindow, from: nil))
        if model.tools.tool == .brush {
            setBrushCursor(point)
        }
        model.tools.mouseDragged(to: point)
        if model.tools.tool == .brush {
            apply(model.refreshPixels(allowEmpty: false))
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let model else { return }
        let point = model.documentPoint(from: convert(event.locationInWindow, from: nil))
        let painting = model.tools.tool == .brush
        model.tools.mouseUp(at: point)
        if painting {
            apply(model.refreshPixels(allowEmpty: false))
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard let model, model.tools.tool == .brush else { return }
        setBrushCursor(model.documentPoint(from: convert(event.locationInWindow, from: nil)))
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
        if model?.tools.tool == .crop, event.keyCode == 53 {
            model?.tools.cancelCrop()
            return
        }
        if model?.tools.tool == .crop, event.keyCode == 36 || event.keyCode == 76 {
            model?.tools.applyCrop()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            model?.tools.deleteSelection()
            return
        }
        super.keyDown(with: event)
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
}
