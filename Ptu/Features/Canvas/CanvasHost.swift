// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct CanvasHost: NSViewRepresentable {
    var canvas: CanvasViewModel
    var tool: EditorTool
    var selection: CGRect?
    var cropRect: CGRect?
    var brushSize: Double
    var renderGeneration: Int
    var zoomRequestID: Int
    var displayGeneration: Int
    var overlayRevision: Int

    func makeNSView(context: Context) -> CanvasView {
        let view = CanvasView()
        view.model = canvas
        return view
    }

    func updateNSView(_ nsView: CanvasView, context: Context) {
        nsView.model = canvas
        nsView.syncFromModel()
        _ = (tool, selection, cropRect, brushSize, renderGeneration, zoomRequestID, displayGeneration, overlayRevision)
    }
}
