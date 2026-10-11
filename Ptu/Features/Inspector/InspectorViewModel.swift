// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation
import Observation

@MainActor
@Observable
final class InspectorViewModel {
    private let document: EditorDocumentSession

    var selectedLayerID: UUID? { document.selectedLayerID }
    var hasSelectedLayer: Bool { document.selectedLayerID != nil }
    var documentWidth: Int { document.model.width }
    var documentHeight: Int { document.model.height }
    var resolutionPPI: Double { document.model.resolutionPPI }

    var foreground: RGBA {
        get { document.foreground }
        set { document.foreground = newValue }
    }

    var background: RGBA {
        get { document.background }
        set { document.background = newValue }
    }

    var selectedName: String {
        guard let selectedLayerID, let node = document.model.node(id: selectedLayerID) else { return "" }
        return node.name
    }

    var blend: BlendMode {
        get { document.model.node(id: document.selectedLayerID ?? UUID())?.blend ?? .normal }
        set { setBlend(newValue) }
    }

    var opacity: Double {
        get { document.model.node(id: document.selectedLayerID ?? UUID())?.opacity ?? 1 }
        set { setOpacity(newValue) }
    }

    init(document: EditorDocumentSession) {
        self.document = document
    }

    @ObservationIgnored var onPickColor: ((Bool) -> Void)?

    func swapColors() {
        document.swapColors()
    }

    func resetColors() {
        foreground = .black
        background = .white
    }

    func pickColor(background: Bool) {
        onPickColor?(background)
    }

    func applySwatch(_ color: RGBA) {
        foreground = color.opaque
    }

    func setSelectedName(_ name: String) {
        guard let id = document.selectedLayerID else { return }
        if document.isCoalescing {
            document.editLive(redraw: .none) { model in
                model.setName(id: id, name: name)
            }
        } else {
            document.edit(redraw: .none) { model in
                model.setName(id: id, name: name)
            }
        }
    }

    func setOpacity(_ opacity: Double) {
        guard let id = document.selectedLayerID else { return }
        if document.isCoalescing {
            document.editLive(redraw: .full) { model in
                model.setOpacity(id: id, opacity: opacity)
            }
        } else {
            document.edit(redraw: .full) { model in
                model.setOpacity(id: id, opacity: opacity)
            }
        }
    }

    func setBlend(_ blend: BlendMode) {
        guard let id = document.selectedLayerID else { return }
        document.edit(redraw: .full) { model in
            model.setBlend(id: id, blend: blend)
        }
    }

    func nameFocusChanged(isFocused: Bool, draft: String) {
        if isFocused {
            document.beginCoalescedEdit()
        } else {
            setSelectedName(draft)
            document.endCoalescedEdit()
        }
    }

    func nameDraftChanged(_ draft: String, isFocused: Bool) {
        if isFocused {
            setSelectedName(draft)
        }
    }

    func opacityEditingChanged(_ editing: Bool) {
        if editing {
            document.beginCoalescedEdit()
        } else {
            document.endCoalescedEdit()
        }
    }

    var selectedIsPixel: Bool {
        guard let id = document.selectedLayerID else { return false }
        return document.model.pixelLayer(id: id) != nil
    }

    var selectedIsAdjustment: Bool {
        guard let id = document.selectedLayerID, let node = document.model.node(id: id) else { return false }
        return node.isAdjustment
    }

    var hasMask: Bool { document.model.node(id: document.selectedLayerID ?? UUID())?.mask != nil }

    var maskEnabled: Bool {
        document.model.node(id: document.selectedLayerID ?? UUID())?.mask?.isEnabled ?? false
    }

    var editsMask: Bool {
        get { document.editsMask }
        set { document.editsMask = newValue }
    }

    var onEditAdjustment: (() -> Void)?

    func isEffectEnabled(_ kind: LayerEffectKind) -> Bool {
        guard let id = document.selectedLayerID, let layer = document.model.pixelLayer(id: id) else { return false }
        return layer.effects.isEnabled(kind)
    }

    func toggleEffect(_ kind: LayerEffectKind) {
        guard let id = document.selectedLayerID else { return }
        document.edit(redraw: .full) { model in
            guard var layer = model.pixelLayer(id: id) else { return }
            var effects = layer.effects
            if effects.contains(kind) {
                effects.setEnabled(!effects.isEnabled(kind), for: kind)
            } else {
                effects.ensure(kind, color: self.document.background)
            }
            model.setEffects(id: id, effects: effects)
        }
    }

    func addMask(revealing: Bool) {
        guard let id = document.selectedLayerID else { return }
        document.editsMask = false
        document.edit(redraw: .full) { model in
            model.addMask(id: id, revealing: revealing)
        }
    }

    func deleteMask() {
        guard let id = document.selectedLayerID else { return }
        document.editsMask = false
        document.edit(redraw: .full) { model in
            model.deleteMask(id: id)
        }
    }

    func invertMask() {
        guard let id = document.selectedLayerID else { return }
        document.edit(redraw: .full) { model in
            model.invertMask(id: id)
        }
    }

    func setMaskEnabled(_ enabled: Bool) {
        guard let id = document.selectedLayerID else { return }
        document.edit(redraw: .full) { model in
            model.setMaskEnabled(id: id, isEnabled: enabled)
        }
    }
}
