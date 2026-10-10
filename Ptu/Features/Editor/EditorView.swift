// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @Binding var document: PtuDocument
    @State private var editor: EditorViewModel

    init(document: Binding<PtuDocument>) {
        _document = document
        _editor = State(initialValue: EditorViewModel(
            model: document.wrappedValue.model,
            needsSetup: document.wrappedValue.prefersSetupSheet
        ))
    }

    var body: some View {
        HSplitView {
            ToolSidebar(model: editor.tools)
                .frame(minWidth: Theme.sidebarMinWidth, idealWidth: Theme.sidebarIdealWidth, maxWidth: 360)
            CanvasHost(
                canvas: editor.canvas,
                tool: editor.tools.tool,
                selection: editor.tools.selection,
                cropRect: editor.tools.cropRect,
                brushSize: editor.tools.brushSize,
                renderGeneration: editor.document.renderGeneration,
                zoomRequestID: editor.canvas.zoomRequestID
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .background(Theme.canvasBackdrop)
            .accessibilityIdentifier("canvas")
            inspectorColumn
        }
        .frame(minWidth: 880, minHeight: 560)
        .background(Theme.windowBackground)
        .toolbar { toolbar }
        .focusedValue(\.editorActions, editor.actions)
        .sheet(isPresented: $editor.needsSetup) {
            NewCanvasSheet(
                model: editor.newCanvas,
                onCreate: { width, height, ppi, background in
                    editor.applyNewCanvas(width: width, height: height, resolutionPPI: ppi, background: background)
                },
                onCancel: { editor.cancelSetup() }
            )
        }
        .fileExporter(
            isPresented: $editor.showExporter,
            document: editor.exportItem,
            contentType: editor.exportType,
            defaultFilename: L10n.Export.filename
        ) { result in
            if case .failure = result {
                editor.exportError = true
            }
        }
        .alert(L10n.Error.exportFailed, isPresented: $editor.exportError) {
            Button {
                editor.exportError = false
            } label: {
                Text(L10n.Action.ok)
            }
        }
        .onAppear { bindDocument() }
    }

    private var inspectorColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                InspectorView(model: editor.inspector)
                LayerListView(model: editor.layers)
            }
            .padding(Theme.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background)
        .frame(minWidth: Theme.inspectorMinWidth, idealWidth: Theme.inspectorIdealWidth, maxWidth: 420)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                editor.canvas.requestZoom(.zoomOut)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help(L10n.View.zoomOut)
            Text(L10n.Status.zoom(editor.canvas.zoomPercent))
                .font(.body.monospacedDigit())
                .frame(minWidth: 64)
            Button {
                editor.canvas.requestZoom(.zoomIn)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help(L10n.View.zoomIn)
            Button {
                editor.canvas.requestZoom(.actualSize)
            } label: {
                Text(L10n.View.actualSize)
            }
            Button {
                editor.canvas.requestZoom(.fit)
            } label: {
                Text(L10n.View.fit)
            }
        }
        if editor.tools.showsCropActions {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    editor.tools.cancelCrop()
                } label: {
                    Text(L10n.Crop.cancel)
                }
                Button {
                    editor.tools.applyCrop()
                } label: {
                    Text(L10n.Crop.apply)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func bindDocument() {
        editor.bind { model in
            document.model = model
        }
    }
}
