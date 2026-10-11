// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

struct ShapeDraft: Equatable, Sendable {
    var kind: ShapeKind
    var anchor: CGPoint
    var current: CGPoint
    var square: Bool
    var fromCenter: Bool

    var rect: CGRect {
        var dx = current.x - anchor.x
        var dy = current.y - anchor.y
        if square {
            let side = max(abs(dx), abs(dy))
            dx = dx < 0 ? -side : side
            dy = dy < 0 ? -side : side
        }
        if fromCenter {
            return CGRect(x: anchor.x - abs(dx), y: anchor.y - abs(dy), width: abs(dx) * 2, height: abs(dy) * 2)
        }
        return CGRect(x: min(anchor.x, anchor.x + dx), y: min(anchor.y, anchor.y + dy), width: abs(dx), height: abs(dy))
    }
}

extension ToolsViewModel {
    func beginType(at point: CGPoint) {
        typeOrigin = point
        focusTypeEditor()
        overlayRevision &+= 1
    }

    /// Puts keyboard focus in the sidebar type field and keeps app shortcuts off.
    func focusTypeEditor() {
        typeSession = true
        typeFieldFocused = true
        typeFocusNonce &+= 1
        TextInsertionFocus.set("type-field", active: true)
    }

    /// Leaves the type session. The draft stays in the sidebar field, and the current tool stays put.
    func endTextEditing() {
        typeSession = false
        typeOrigin = nil
        typeFieldFocused = false
        TextInsertionFocus.set("type-field", active: false)
        overlayRevision &+= 1
    }

    func deleteTypeCharacter() {
        guard isEditingText, !typeText.isEmpty else { return }
        typeText.removeLast()
        overlayRevision &+= 1
    }

    func commitType() {
        guard let origin = typeOrigin else { return }
        let text = typeText
        guard !text.isEmpty, let layout = TypeRaster.render(text: text, fontSize: typeFontSize, color: document.foreground) else { return }
        let name = String(text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(40))
        let title = name.isEmpty ? L10n.Tool.type : name
        var newID: UUID?
        document.edit(redraw: .full) { model in
            newID = model.insertPixelLayer(
                name: title,
                originX: Int(origin.x.rounded(.down)),
                originY: Int(origin.y.rounded(.down)),
                buffer: layout.buffer
            )
        }
        if let newID { document.selectedLayerID = newID }
        typeOrigin = nil
        typeText = ""
    }

    var typePreview: TypeRaster.Layout? {
        guard tool == .type, let origin = typeOrigin else { return nil }
        return TypeRaster.render(text: typeText, fontSize: typeFontSize, color: document.foreground).map { layout in
            TypeRaster.Layout(buffer: layout.buffer, caret: layout.caret.offsetBy(dx: origin.x, dy: origin.y))
        }
    }

    func beginShape(at point: CGPoint, shift: Bool, option: Bool) {
        shapeDraft = ShapeDraft(kind: shapeKind, anchor: point, current: point, square: shift, fromCenter: option)
    }

    func dragShape(to point: CGPoint, shift: Bool, option: Bool) {
        guard var draft = shapeDraft else { return }
        draft.current = point
        draft.square = shift
        draft.fromCenter = option
        shapeDraft = draft
        overlayRevision &+= 1
    }

    func finishShape() {
        guard let draft = shapeDraft else { return }
        shapeDraft = nil
        let color = document.foreground.opaque
        let placed: PlacedRaster?
        switch draft.kind {
        case .rectangle:
            placed = ShapeRaster.rectangle(draft.rect, color: color, cornerRadius: shapeCornerRadius)
        case .ellipse:
            placed = ShapeRaster.ellipse(draft.rect, color: color)
        case .line:
            let end = draft.square ? snappedLineEnd(from: draft.anchor, to: draft.current) : draft.current
            placed = ShapeRaster.line(from: draft.anchor, to: end, thickness: shapeLineWidth, color: color)
        }
        guard let placed else { return }
        let names = document.model.layers.map(\.name)
        var number = 1
        let title = draft.kind == .rectangle ? L10n.Shape.rectangle : draft.kind == .ellipse ? L10n.Shape.ellipse : L10n.Shape.line
        while names.contains(L10n.Shape.layerName(title, number)) { number += 1 }
        let name = L10n.Shape.layerName(title, number)
        var newID: UUID?
        document.edit(redraw: .full) { model in
            newID = model.insertPixelLayer(name: name, originX: placed.originX, originY: placed.originY, buffer: placed.buffer)
        }
        if let newID { document.selectedLayerID = newID }
    }

    func beginGradient(at point: CGPoint) {
        gradientStart = point
        gradientEnd = point
        overlayRevision &+= 1
    }

    func dragGradient(to point: CGPoint) {
        guard gradientStart != nil else { return }
        gradientEnd = point
        overlayRevision &+= 1
    }

    func finishGradient() {
        guard let start = gradientStart, let end = gradientEnd else { return }
        gradientStart = nil
        gradientEnd = nil
        guard hypot(end.x - start.x, end.y - start.y) >= 0.5,
              let id = document.selectedLayerID,
              document.model.pixelLayer(id: id) != nil else { return }
        let foreground = document.foreground.opaque
        let background = gradientFade == .toBackground ? document.background.opaque : RGBA(r: foreground.r, g: foreground.g, b: foreground.b, a: 0)
        let from = gradientReversed ? background : foreground
        let to = gradientReversed ? foreground : background
        let coverage = selection?.resolvedCoverage()
        let canvasWidth = document.model.width
        let kind = gradientKind
        document.edit(redraw: .full) { model in
            guard var layer = model.pixelLayer(id: id) else { return }
            GradientRaster.paint(
                buffer: &layer.buffer,
                originX: layer.originX,
                originY: layer.originY,
                kind: kind,
                start: start,
                end: end,
                from: from,
                to: to,
                opacity: 1,
                coverage: coverage,
                canvasWidth: canvasWidth
            )
            model.replacePixelBuffer(id: id, buffer: layer.buffer)
        }
    }

    func contentAwareFill() {
        guard let selection, !selection.isEmpty, let id = document.selectedLayerID else {
            toolMessage = L10n.Error.fillNoSource
            return
        }
        let coverage = selection.resolvedCoverage()
        let canvasWidth = document.model.width
        var filled = false
        document.edit(redraw: .rect(selection.bounds.insetBy(dx: -2, dy: -2))) { model in
            guard var layer = model.pixelLayer(id: id) else { return }
            filled = ContentFill.fill(
                buffer: &layer.buffer,
                coverage: coverage,
                canvasWidth: canvasWidth,
                originX: layer.originX,
                originY: layer.originY
            )
            if filled { model.replacePixelBuffer(id: id, buffer: layer.buffer) }
        }
        toolMessage = filled ? nil : L10n.Error.fillNoSource
    }

    func selectSubject() {
        guard let buffer = CanvasSample.composite(document.canvasModel()) ?? sampleBuffer(),
              let image = buffer.cgImage(),
              let mask = SubjectRemoval.visionMask(in: image, width: buffer.width, height: buffer.height),
              let selection = PixelSelection.covering(mask.map { $0 >= 128 ? 255 : 0 }, width: buffer.width, height: buffer.height) else {
            toolMessage = L10n.Error.noSubject
            return
        }
        self.selection = selection
        toolMessage = nil
    }

    func removeBackground() {
        guard let id = document.selectedLayerID, let layer = document.model.pixelLayer(id: id) else { return }
        switch SubjectRemoval.removeBackground(from: layer.buffer) {
        case .noSubject:
            toolMessage = L10n.Error.noSubject
        case .changed(let buffer):
            toolMessage = nil
            document.edit(redraw: .full) { model in
                model.replacePixelBuffer(id: id, buffer: buffer)
            }
        }
    }

    private func snappedLineEnd(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
        let length = hypot(dx, dy)
        return CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
    }
}
