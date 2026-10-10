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

    func swapColors() {
        document.swapColors()
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
}
