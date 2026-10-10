// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation
import Observation

@MainActor
@Observable
final class LayersViewModel {
    private let document: EditorDocumentSession

    var layers: [LayerNode] { document.model.layers }

    var selectedLayerID: UUID? {
        get { document.selectedLayerID }
        set { document.selectedLayerID = newValue }
    }

    init(document: EditorDocumentSession) {
        self.document = document
    }

    func addLayer() {
        var newID: UUID?
        document.edit(redraw: .full) { model in
            newID = model.addPixelLayer()
        }
        if let newID {
            document.selectedLayerID = newID
        }
    }

    func addGroup() {
        var newID: UUID?
        document.edit(redraw: .none) { model in
            newID = model.addGroup()
        }
        if let newID {
            document.selectedLayerID = newID
        }
    }

    func deleteSelected() {
        guard let id = document.selectedLayerID else { return }
        document.edit(redraw: .full) { model in
            model.delete(id: id)
        }
        if document.model.node(id: id) == nil {
            document.selectedLayerID = document.model.layers.first?.id
        }
    }

    func deleteRoot(at offsets: IndexSet) {
        let ids = offsets.compactMap { index -> UUID? in
            guard document.model.layers.indices.contains(index) else { return nil }
            return document.model.layers[index].id
        }
        guard !ids.isEmpty else { return }
        document.edit(redraw: .full) { model in
            for id in ids {
                model.delete(id: id)
            }
        }
        document.repairSelection()
    }

    func duplicateSelected() {
        guard let id = document.selectedLayerID else { return }
        var newID: UUID?
        document.edit(redraw: .full) { model in
            newID = model.duplicate(id: id)
        }
        if let newID {
            document.selectedLayerID = newID
        }
    }

    func bringForward() {
        guard let id = document.selectedLayerID else { return }
        document.edit(redraw: .full) { model in
            model.move(id: id, towardFront: true)
        }
    }

    func sendBackward() {
        guard let id = document.selectedLayerID else { return }
        document.edit(redraw: .full) { model in
            model.move(id: id, towardFront: false)
        }
    }

    func moveRoot(from offsets: IndexSet, to destination: Int) {
        document.edit(redraw: .full) { model in
            model.move(parentID: nil, from: offsets, to: destination)
        }
    }

    func moveChildren(of parentID: UUID, from offsets: IndexSet, to destination: Int) {
        document.edit(redraw: .full) { model in
            model.move(parentID: parentID, from: offsets, to: destination)
        }
    }

    func toggleVisible(_ id: UUID) {
        guard let node = document.model.node(id: id) else { return }
        document.edit(redraw: .full) { model in
            model.setVisible(id: id, isVisible: !node.isVisible)
        }
    }
}
