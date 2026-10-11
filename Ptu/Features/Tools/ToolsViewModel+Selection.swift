// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import CoreGraphics
import Foundation

extension ToolsViewModel {
    func endPreviousTool(_ previous: EditorTool) {
        if previous == .type { commitType() }
        if floating != nil, tool != .move { commitFloating() }
        lassoDraft = []
        lassoCursor = nil
        shapeDraft = nil
        gradientStart = nil
        gradientEnd = nil
        selectionDraft = nil
        healDabs = []
        movingSelection = false
    }

    func selectAll() {
        selection = PixelSelection.all(width: document.model.width, height: document.model.height)
    }

    func deselect() {
        selection = nil
        selectionDraft = nil
    }

    func inverseSelection() {
        selection = selection?.inverted()
    }

    func featherSelection() {
        guard let selection, !selection.isEmpty else { return }
        self.selection = selection.feathered(by: featherAmount)
    }

    func applyMask(_ coverage: [UInt8]?, shift: Bool, option: Bool) {
        let mode: SelectionMode = option ? .subtract : (shift ? .add : .replace)
        guard let coverage, let next = PixelSelection.covering(coverage, width: document.model.width, height: document.model.height) else {
            if mode == .replace { selection = nil }
            return
        }
        if mode == .replace || selection == nil {
            selection = mode == .subtract ? selection : next
            if mode == .subtract { selection = selection?.combining(next, mode: .subtract) }
            return
        }
        selection = selection?.combining(next, mode: mode)
    }

    func sampleBuffer() -> PixelBuffer? {
        if sampleAllLayers {
            return CanvasSample.composite(document.canvasModel())
        }
        guard let id = document.selectedLayerID, let layer = document.model.pixelLayer(id: id) else { return nil }
        return CanvasSample.layer(layer, width: document.model.width, height: document.model.height)
    }

    func beginLasso(at point: CGPoint, shift: Bool, option: Bool, clickCount: Int) {
        let mode: SelectionMode = option ? .subtract : (shift ? .add : .replace)
        if lassoDraft.isEmpty {
            marqueeMode = mode
            selectionAtGesture = mode == .replace ? nil : selection
            if mode == .replace, let selection, selection.contains(point), lassoKind == .freehand {
                movingSelection = true
                selectionMoveOrigin = selection
                selectionMoveAnchor = point
                return
            }
        }
        if lassoKind == .polygonal {
            if lassoDraft.count >= 3, let first = lassoDraft.first, hypot(point.x - first.x, point.y - first.y) <= max(4, 8 / max(interactionZoom, 0.05)) || clickCount > 1 {
                closeLasso()
                return
            }
            lassoDraft.append(point)
            lassoCursor = point
            overlayRevision &+= 1
            return
        }
        lassoDraft = [point]
        overlayRevision &+= 1
    }

    func dragLasso(to point: CGPoint) {
        if movingSelection, let origin = selectionMoveOrigin, let anchor = selectionMoveAnchor {
            selection = origin.offset(dx: Int((point.x - anchor.x).rounded()), dy: Int((point.y - anchor.y).rounded()))
            return
        }
        guard lassoKind == .freehand else {
            lassoCursor = point
            overlayRevision &+= 1
            return
        }
        if let last = lassoDraft.last, hypot(point.x - last.x, point.y - last.y) < 0.75 { return }
        lassoDraft.append(point)
        overlayRevision &+= 1
    }

    func finishLasso(at point: CGPoint, clickCount: Int) {
        if movingSelection {
            movingSelection = false
            selectionMoveOrigin = nil
            selectionMoveAnchor = nil
            return
        }
        guard lassoKind == .freehand else { return }
        closeLasso()
    }

    func closeLasso() {
        let points = lassoDraft
        lassoDraft = []
        lassoCursor = nil
        guard let draft = PixelSelection.polygon(points, width: document.model.width, height: document.model.height) else {
            if marqueeMode == .replace { selection = nil }
            return
        }
        if marqueeMode == .replace || selectionAtGesture == nil && marqueeMode == .add {
            selection = marqueeMode == .subtract ? selectionAtGesture?.combining(draft, mode: .subtract) : draft
        } else if let base = selectionAtGesture {
            selection = base.combining(draft, mode: marqueeMode)
        }
        selectionAtGesture = nil
    }

    func applyWand(at point: CGPoint, shift: Bool, option: Bool) {
        guard let buffer = sampleBuffer() else { return }
        let coverage = MagicWand.mask(
            in: buffer,
            at: point,
            tolerance: Int(wandTolerance.rounded()),
            contiguous: wandContiguous
        )
        applyMask(coverage, shift: shift, option: option)
        toolMessage = coverage == nil ? L10n.Selection.noMatch : nil
    }

    func applyObjectSelection(at point: CGPoint, shift: Bool, option: Bool) {
        guard let buffer = sampleBuffer() else { return }
        let edge = Int(objectEdgeOffset.rounded())
        let coverage = ObjectSelection.mask(in: buffer, at: point, edgeOffset: edge)
        applyMask(coverage, shift: shift, option: option)
        toolMessage = coverage == nil ? L10n.Error.noSubject : nil
    }

    func sampleColorRange(at point: CGPoint, shift: Bool, option: Bool) {
        guard let buffer = sampleBuffer(), let color = ColorRangeSelection.sampleColor(in: buffer, at: point) else { return }
        if option {
            colorExclude.append(color)
        } else if shift {
            colorInclude.append(color)
        } else {
            colorInclude = [color]
            colorExclude = []
        }
        refreshColorRange()
    }

    func refreshColorRange() {
        guard tool == .colorRange, !colorInclude.isEmpty, let buffer = sampleBuffer() else { return }
        let coverage = ColorRangeSelection.mask(
            in: buffer,
            include: colorInclude,
            exclude: colorExclude,
            fuzziness: Int(colorFuzziness.rounded()),
            invert: false
        )
        selection = PixelSelection.covering(coverage, width: document.model.width, height: document.model.height)
    }

    func copySelection() {
        guard let id = document.selectedLayerID, let layer = document.model.pixelLayer(id: id) else { return }
        if let selection, !selection.isEmpty {
            copiedPixels = SelectionClipboard.copy(layer: layer, selection: selection)
        } else {
            copiedPixels = SelectionClipboard.copyLayer(layer)
        }
        if let copied = copiedPixels, let image = copied.pixels.cgImage(),
           let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(png, forType: .png)
        }
        toolMessage = copiedPixels == nil ? L10n.Selection.noMatch : nil
    }

    func cutSelection() {
        guard hasSelection else { return }
        copySelection()
        deleteSelection()
    }

    func pasteSelection() {
        guard let copied = copiedPixels else { return }
        let name = L10n.Layer.defaultName(document.model.nextLayerNumber)
        var newID: UUID?
        document.edit(redraw: .full) { model in
            newID = model.insertPixelLayer(name: name, originX: copied.originX, originY: copied.originY, buffer: copied.pixels)
        }
        if let newID { document.selectedLayerID = newID }
        selection = nil
    }

    func beginFloating() {
        guard let selection, !selection.isEmpty, let id = document.selectedLayerID,
              let layer = document.model.pixelLayer(id: id),
              let lift = FloatingSelection.lift(layer: layer, selection: selection) else { return }
        document.beginCoalescedEdit()
        document.editLive(redraw: .rect(selection.bounds.insetBy(dx: -1, dy: -1))) { model in
            model.replacePixelBuffer(id: id, buffer: lift.cleared)
        }
        floating = lift.floating
        self.selection = nil
        if tool != .move { tool = .move }
    }

    func beginFloatingDrag(at point: CGPoint) {
        floatLast = point
        floatRemainder = .zero
    }

    func dragFloating(to point: CGPoint) {
        guard var floating, let last = floatLast else { return }
        floatRemainder.x += point.x - last.x
        floatRemainder.y += point.y - last.y
        let dx = Int(floatRemainder.x.rounded(.towardZero))
        let dy = Int(floatRemainder.y.rounded(.towardZero))
        if dx != 0 || dy != 0 {
            floatRemainder.x -= CGFloat(dx)
            floatRemainder.y -= CGFloat(dy)
            floating.originX += dx
            floating.originY += dy
            self.floating = floating
            overlayRevision &+= 1
        }
        floatLast = point
    }

    func endFloatingDrag() {
        floatLast = nil
    }

    func commitFloating() {
        guard let floating else { return }
        let placed = floating
        self.floating = nil
        document.editLive(redraw: .full) { model in
            guard var layer = model.pixelLayer(id: placed.layerID) else { return }
            FloatingSelection.stamp(placed, into: &layer)
            model.replacePixelBuffer(id: placed.layerID, buffer: layer.buffer, originX: layer.originX, originY: layer.originY)
        }
        document.endCoalescedEdit()
    }

    func cancelFloating() {
        guard floating != nil else { return }
        floating = nil
        document.cancelCoalescedEdit()
    }

    func handleKey(characters: String, keyCode: UInt16, command: Bool) -> Bool {
        _ = (characters, command)
        if keyCode == 53 {
            if floating != nil { cancelFloating(); return true }
            if !lassoDraft.isEmpty { lassoDraft = []; lassoCursor = nil; return true }
            if shapeDraft != nil { shapeDraft = nil; return true }
            if gradientStart != nil { gradientStart = nil; gradientEnd = nil; return true }
            if isEditingText { endTextEditing(); return true }
            return false
        }
        if keyCode == 36 || keyCode == 76 {
            if floating != nil { commitFloating(); return true }
            if lassoKind == .polygonal, lassoDraft.count >= 3 { closeLasso(); return true }
            if tool == .type { commitType(); return true }
            if gradientStart != nil { finishGradient(); return true }
            return false
        }
        if (keyCode == 51 || keyCode == 117), tool != .type {
            deleteSelection()
            return true
        }
        return false
    }
}
