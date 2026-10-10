// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation
import Observation

/// Coordination point for feature view models.
/// Document edits, history, and paint preview go through this type.
/// Feature views do not mutate `DocumentModel` themselves.
@MainActor
protocol DocumentSession: AnyObject {
    var model: DocumentModel { get }
    var selectedLayerID: UUID? { get set }
    var foreground: RGBA { get set }
    var background: RGBA { get set }
    var renderGeneration: Int { get }
    var canUndo: Bool { get }
    var canRedo: Bool { get }
    var isCoalescing: Bool { get }
    var onModelChange: ((DocumentModel) -> Void)? { get set }

    func undo()
    func redo()
    func beginCoalescedEdit()
    func endCoalescedEdit()
    func edit(redraw: Redraw, _ body: (inout DocumentModel) -> Void)
    func editLive(redraw: Redraw, _ body: (inout DocumentModel) -> Void)
    func replaceDocument(_ model: DocumentModel)
    func repairSelection()
    func swapColors()
    func canvasModel() -> DocumentModel
    func consumeDirty() -> (full: Bool, rect: CGRect)
    func consumeCanvasOriginShift() -> CGPoint?
    func shiftCanvasOrigin(to point: CGPoint)
    func withPaintingModel(_ body: (inout DocumentModel) -> Void)
    func notePaintDirty(_ rect: CGRect)
    func commitPainting()
}

@MainActor
@Observable
final class EditorDocumentSession: DocumentSession {
    private(set) var model: DocumentModel
    var selectedLayerID: UUID?
    var foreground: RGBA = .black
    var background: RGBA = .white
    private(set) var renderGeneration = 1

    @ObservationIgnored var onModelChange: ((DocumentModel) -> Void)?
    @ObservationIgnored private var history = DocumentHistory()
    @ObservationIgnored private var gestureSnapshot: DocumentModel?
    @ObservationIgnored private var coalesceDepth = 0
    @ObservationIgnored private var dirtyFull = true
    @ObservationIgnored private var accumulatedDirty: CGRect = .null
    @ObservationIgnored private var painting: DocumentModel?
    @ObservationIgnored private var canvasOriginShift: CGPoint?

    var canUndo: Bool { coalesceDepth == 0 && history.canUndo }
    var canRedo: Bool { coalesceDepth == 0 && history.canRedo }
    var isCoalescing: Bool { coalesceDepth > 0 }

    init(model: DocumentModel) {
        self.model = model
        selectedLayerID = model.layers.first?.id
    }

    func undo() {
        guard coalesceDepth == 0, let restored = history.undo(current: model) else { return }
        model = restored
        repairSelection()
        markDirty(.full)
        publish()
    }

    func redo() {
        guard coalesceDepth == 0, let restored = history.redo(current: model) else { return }
        model = restored
        repairSelection()
        markDirty(.full)
        publish()
    }

    func beginCoalescedEdit() {
        if coalesceDepth == 0 {
            gestureSnapshot = model
        }
        coalesceDepth += 1
    }

    func endCoalescedEdit() {
        guard coalesceDepth > 0 else { return }
        coalesceDepth -= 1
        guard coalesceDepth == 0 else { return }
        if let snapshot = gestureSnapshot, snapshot != model {
            history.push(snapshot)
        }
        gestureSnapshot = nil
        publish()
    }

    func edit(redraw: Redraw, _ body: (inout DocumentModel) -> Void) {
        let before = model
        body(&model)
        guard before != model else { return }
        history.push(before)
        markDirty(redraw)
        publish()
    }

    func editLive(redraw: Redraw, _ body: (inout DocumentModel) -> Void) {
        body(&model)
        markDirty(redraw)
        publish()
    }

    func replaceDocument(_ replacement: DocumentModel) {
        painting = nil
        model = replacement
        history.clear()
        gestureSnapshot = nil
        coalesceDepth = 0
        selectedLayerID = model.layers.first?.id
        markDirty(.full)
        publish()
    }

    func repairSelection() {
        if let selectedLayerID, model.node(id: selectedLayerID) == nil {
            self.selectedLayerID = model.layers.first?.id
        }
    }

    func swapColors() {
        let swap = foreground
        foreground = background
        background = swap
    }

    func canvasModel() -> DocumentModel {
        painting ?? model
    }

    func consumeDirty() -> (full: Bool, rect: CGRect) {
        let update = (full: dirtyFull, rect: accumulatedDirty)
        dirtyFull = false
        accumulatedDirty = .null
        return update
    }

    func consumeCanvasOriginShift() -> CGPoint? {
        let shift = canvasOriginShift
        canvasOriginShift = nil
        return shift
    }

    func shiftCanvasOrigin(to point: CGPoint) {
        canvasOriginShift = point
    }

    func withPaintingModel(_ body: (inout DocumentModel) -> Void) {
        if painting == nil {
            painting = model
        }
        var live = painting ?? model
        body(&live)
        painting = live
    }

    func notePaintDirty(_ rect: CGRect) {
        if accumulatedDirty.isNull {
            accumulatedDirty = rect
        } else {
            accumulatedDirty = accumulatedDirty.union(rect)
        }
    }

    func commitPainting() {
        guard let painted = painting else { return }
        let dirty = accumulatedDirty
        model = painted
        painting = nil
        if dirty.isNull || dirty.isEmpty {
            markDirty(.full)
        } else {
            markDirty(.rect(dirty))
        }
    }

    private func markDirty(_ redraw: Redraw) {
        switch redraw {
        case .none:
            return
        case .full:
            dirtyFull = true
            renderGeneration += 1
        case .rect(let rect):
            if !dirtyFull {
                accumulatedDirty = accumulatedDirty.union(rect)
            }
            renderGeneration += 1
        }
    }

    private func publish() {
        onModelChange?(model)
    }
}
