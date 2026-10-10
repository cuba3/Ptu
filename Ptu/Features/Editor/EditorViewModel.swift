// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class EditorViewModel {
    var needsSetup: Bool
    let document: EditorDocumentSession
    let tools: ToolsViewModel
    let layers: LayersViewModel
    let inspector: InspectorViewModel
    let canvas: CanvasViewModel
    let newCanvas = NewCanvasViewModel()

    var showExporter = false
    var exportItem: ExportedImage?
    var exportType: UTType = .png
    var exportError = false

    init(model: DocumentModel, needsSetup: Bool) {
        document = EditorDocumentSession(model: model)
        tools = ToolsViewModel(document: document)
        layers = LayersViewModel(document: document)
        inspector = InspectorViewModel(document: document)
        canvas = CanvasViewModel(document: document, tools: tools)
        self.needsSetup = needsSetup
    }

    var actions: EditorActions {
        EditorActions(
            canUndo: document.canUndo,
            canRedo: document.canRedo,
            undo: { [document] in document.undo() },
            redo: { [document] in document.redo() },
            deleteSelection: { [tools] in tools.deleteSelection() },
            hasSelection: tools.selection != nil,
            exportPNG: { [weak self] in self?.exportPNG() },
            exportJPEG: { [weak self] in self?.exportJPEG() },
            zoomIn: { [canvas] in canvas.requestZoom(.zoomIn) },
            zoomOut: { [canvas] in canvas.requestZoom(.zoomOut) },
            actualSize: { [canvas] in canvas.requestZoom(.actualSize) },
            fit: { [canvas] in canvas.requestZoom(.fit) }
        )
    }

    func bind(onModelChange: @escaping (DocumentModel) -> Void) {
        document.onModelChange = onModelChange
    }

    func applyNewCanvas(width: Int, height: Int, resolutionPPI: Double, background: CanvasBackground) {
        tools.resetForNewCanvas()
        canvas.requestZoom(.fit)
        needsSetup = false
        document.replaceDocument(DocumentModel.blank(
            width: width,
            height: height,
            resolutionPPI: resolutionPPI,
            background: background
        ))
    }

    func cancelSetup() {
        needsSetup = false
    }

    private func exportPNG() {
        export(type: .png)
    }

    private func exportJPEG() {
        export(type: .jpeg)
    }

    private func export(type: UTType) {
        guard let image = Compositor.render(document.model) else {
            exportError = true
            return
        }
        do {
            let data: Data
            if type == .jpeg {
                data = try ImageFiles.jpegData(from: image, ppi: document.model.resolutionPPI)
            } else {
                data = try ImageFiles.pngData(from: image, ppi: document.model.resolutionPPI)
            }
            exportItem = ExportedImage(data: data)
            exportType = type
            showExporter = true
        } catch {
            exportError = true
        }
    }
}
