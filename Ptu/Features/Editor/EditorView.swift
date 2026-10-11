// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @Binding var document: PtuDocument
    let fileURL: URL?
    @State private var editor: EditorViewModel
    @State private var tabID: UUID?
    @State private var window: NSWindow?

    init(document: Binding<PtuDocument>, fileURL: URL?) {
        _document = document
        self.fileURL = fileURL
        _editor = State(initialValue: EditorViewModel(
            model: document.wrappedValue.model,
            needsSetup: document.wrappedValue.prefersSetupSheet,
            importNotes: document.wrappedValue.importNotes
        ))
    }

    var body: some View {
        workspace
            .background {
                EditorWindowReader { resolved in
                    adopt(resolved)
                }
            }
            .modifier(EditorGeometrySheets(editor: editor))
            .modifier(EditorImportSheets(
                editor: editor,
                fileURL: fileURL,
                model: document.model,
                jpegPresented: jpegPresented,
                colorPresented: colorPresented,
                psdPresented: psdPresented,
                psdChoosing: psdChoosing,
                importErrorPresented: importErrorPresented,
                reloadPresented: reloadPresented,
                onAppear: bindAndWatch,
                onFileURL: { url in
                    editor.watchFile(url)
                    if let url { RecentFiles.shared.note(url) }
                    refreshTabTitle()
                },
                onModel: { editor.adoptExternal($0) },
                onDisappear: {
                    if let tabID {
                        DocumentTabCenter.shared.unregister(id: tabID)
                    }
                },
                onBecomeKey: { key in
                    guard let key, key == window, let tabID else { return }
                    DocumentTabCenter.shared.becomeKey(
                        id: tabID,
                        window: key,
                        handler: { [editor] command in editor.perform(command) },
                        isEditingText: { [editor] in editor.tools.isEditingText }
                    )
                    refreshTabTitle()
                },
                onResignKey: { key in
                    guard let key, key == window, let tabID else { return }
                    DocumentTabCenter.shared.resignKey(id: tabID)
                }
            ))
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            DocumentTabBar(center: DocumentTabCenter.shared)
            HSplitView {
                ToolSidebar(model: editor.tools)
                    .frame(minWidth: Theme.sidebarMinWidth, idealWidth: Theme.sidebarIdealWidth, maxWidth: 360)
                CanvasHost(
                    canvas: editor.canvas,
                    tool: editor.tools.tool,
                    selection: editor.tools.selection?.bounds,
                    cropRect: editor.tools.cropRect,
                    brushSize: editor.tools.brushSize,
                    renderGeneration: editor.document.renderGeneration,
                    zoomRequestID: editor.canvas.zoomRequestID,
                    displayGeneration: editor.canvas.displayGeneration,
                    overlayRevision: editor.tools.overlayRevision
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                .background(Theme.canvasBackdrop)
                .accessibilityIdentifier("canvas")
                inspectorColumn
            }
        }
        .frame(minWidth: 880, minHeight: 560)
        .background(Theme.windowBackground)
        .toolbar { toolbar }
        .focusedValue(\.editorActions, editor.actions)
    }

    private func bindAndWatch() {
        bindDocument()
        editor.watchFile(fileURL)
        if let fileURL {
            RecentFiles.shared.note(fileURL)
        }
        registerTabIfNeeded()
    }

    private var jpegPresented: Binding<Bool> {
        Binding(get: { editor.showJPEGSheet }, set: { editor.showJPEGSheet = $0 })
    }

    private var colorPresented: Binding<Bool> {
        Binding(
            get: { editor.colorPicker.isPresented },
            set: { if !$0 { editor.colorPicker.cancel() } }
        )
    }

    private var psdPresented: Binding<Bool> {
        Binding(
            get: { editor.psdImport.request != nil },
            set: { if !$0 { editor.psdImport.cancel() } }
        )
    }

    private var psdChoosing: Binding<Bool> {
        Binding(
            get: { editor.psdImport.isChoosingFile },
            set: { editor.psdImport.isChoosingFile = $0 }
        )
    }

    private var importErrorPresented: Binding<Bool> {
        Binding(
            get: { editor.psdImport.errorMessage != nil },
            set: { if !$0 { editor.psdImport.errorMessage = nil } }
        )
    }

    private var reloadPresented: Binding<Bool> {
        Binding(
            get: { editor.reloader.showPrompt },
            set: { editor.reloader.showPrompt = $0 }
        )
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
        zoomToolbar
        if editor.canvas.isTransforming {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    editor.performGeometry(.cancelTransform)
                } label: {
                    Text(L10n.Geometry.cancel)
                }
                Button {
                    editor.performGeometry(.applyTransform)
                } label: {
                    Text(L10n.Geometry.apply)
                }
                .buttonStyle(.borderedProminent)
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

    @ToolbarContentBuilder
    private var zoomToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                editor.toggleCommandPalette()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help(L10n.Menu.commandPalette)
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
        }
        ToolbarItemGroup(placement: .automatic) {
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
    }

    private func bindDocument() {
        editor.bind { model in
            document.model = model
        }
        editor.closeWindow = { [window] in
            window?.close()
        }
    }

    private func adopt(_ resolved: NSWindow) {
        window = resolved
        resolved.tabbingMode = .disallowed
        editor.attach(window: resolved)
        registerTabIfNeeded()
        refreshTabTitle()
        if resolved.isKeyWindow, let tabID {
            DocumentTabCenter.shared.becomeKey(
                id: tabID,
                window: resolved,
                handler: { [editor] command in editor.perform(command) },
                isEditingText: { [editor] in editor.tools.isEditingText }
            )
        }
    }

    private func registerTabIfNeeded() {
        guard tabID == nil else { return }
        let id = DocumentTabCenter.shared.register(
            title: tabTitle,
            activate: { [window] in window?.makeKeyAndOrderFront(nil) },
            close: { [window] in window?.close() }
        )
        tabID = id
    }

    private func refreshTabTitle() {
        guard let tabID else { return }
        DocumentTabCenter.shared.update(id: tabID, title: tabTitle)
    }

    private var tabTitle: String {
        if let title = window?.title, !title.isEmpty { return title }
        if let fileURL { return fileURL.deletingPathExtension().lastPathComponent }
        return L10n.Tabs.untitled
    }
}

private struct EditorGeometrySheets: ViewModifier {
    @Bindable var editor: EditorViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $editor.adjustment) { sheet in
                AdjustmentSheet(model: sheet) {
                    sheet.apply()
                    editor.adjustment = nil
                } onCancel: {
                    editor.adjustment = nil
                }
            }
            .fileImporter(
                isPresented: $editor.showRawImporter,
                allowedContentTypes: [.rawImage],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    editor.presentRaw(url)
                }
            }
            .sheet(isPresented: $editor.needsSetup) {
                NewCanvasSheet(
                    model: editor.newCanvas,
                    onCreate: { width, height, ppi, background in
                        editor.applyNewCanvas(width: width, height: height, resolutionPPI: ppi, background: background)
                    },
                    onCancel: { editor.cancelSetup() }
                )
            }
            .sheet(isPresented: $editor.showsCanvasSize) {
                CanvasSizeSheet(
                    width: editor.document.model.width,
                    height: editor.document.model.height,
                    onApply: { width, height, anchor in
                        editor.applyCanvasSize(width: width, height: height, anchor: anchor)
                    },
                    onCancel: { editor.showsCanvasSize = false }
                )
            }
            .sheet(isPresented: $editor.showsImageSize) {
                ImageSizeSheet(
                    width: editor.document.model.width,
                    height: editor.document.model.height,
                    resolution: editor.document.model.resolutionPPI,
                    onApply: { width, height, ppi, sampling in
                        editor.applyImageSize(width: width, height: height, resolutionPPI: ppi, sampling: sampling)
                    },
                    onCancel: { editor.showsImageSize = false }
                )
            }
            .sheet(isPresented: $editor.showsTrim) {
                TrimSheet(
                    onApply: { editor.applyTrim($0) },
                    onCancel: { editor.showsTrim = false }
                )
            }
            .sheet(isPresented: $editor.showsGridSettings) {
                GridSettingsSheet(canvas: editor.canvas) {
                    editor.showsGridSettings = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .ptuApplyTransform)) { _ in
                editor.performGeometry(.applyTransform)
            }
            .alert(
                editor.geometryMessage ?? "",
                isPresented: Binding(
                    get: { editor.geometryMessage != nil },
                    set: { if !$0 { editor.geometryMessage = nil } }
                )
            ) {
                Button(L10n.Action.ok) { editor.geometryMessage = nil }
            }
    }
}

private struct EditorImportSheets: ViewModifier {
    @Bindable var editor: EditorViewModel
    var fileURL: URL?
    var model: DocumentModel
    var jpegPresented: Binding<Bool>
    var colorPresented: Binding<Bool>
    var psdPresented: Binding<Bool>
    var psdChoosing: Binding<Bool>
    var importErrorPresented: Binding<Bool>
    var reloadPresented: Binding<Bool>
    var onAppear: () -> Void
    var onFileURL: (URL?) -> Void
    var onModel: (DocumentModel) -> Void
    var onDisappear: () -> Void
    var onBecomeKey: (NSWindow?) -> Void
    var onResignKey: (NSWindow?) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: jpegPresented) {
                JPEGExportSheet(
                    model: editor.jpegExport,
                    onExport: { editor.confirmJPEGExport() },
                    onCancel: { editor.showJPEGSheet = false }
                )
            }
            .sheet(isPresented: colorPresented) {
                ColorPickerSheet(model: editor.colorPicker)
            }
            .sheet(isPresented: psdPresented) {
                if let request = editor.psdImport.request {
                    PSDConversionSheet(
                        request: request,
                        onConfirm: { editor.psdImport.confirm() },
                        onCancel: { editor.psdImport.cancel() }
                    )
                }
            }
            .fileImporter(
                isPresented: psdChoosing,
                allowedContentTypes: [UTType.photoshopDocument, UTType.photoshopLargeDocument],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    editor.psdImport.load(url: url)
                }
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
                Button(L10n.Action.ok) { editor.exportError = false }
            }
            .alert(L10n.PSD.importTitle, isPresented: importErrorPresented) {
                Button(L10n.Action.ok) { editor.psdImport.errorMessage = nil }
            } message: {
                Text(editor.psdImport.errorMessage ?? "")
            }
            .alert(L10n.Reload.title, isPresented: reloadPresented) {
                Button(L10n.Reload.revert) { editor.reloader.revert() }
                Button(L10n.Reload.keep, role: .cancel) { editor.reloader.keepMine() }
            } message: {
                Text(L10n.Reload.message)
            }
            .overlay(alignment: .top) {
                if let palette = editor.commandPalette {
                    CommandPaletteView(model: palette) {
                        editor.commandPalette = nil
                    }
                    .padding(.top, 12)
                }
            }
            .onAppear(perform: onAppear)
            .onChange(of: fileURL, perform: onFileURL)
            .onChange(of: model, perform: onModel)
            .onDisappear(perform: onDisappear)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
                if let key = note.object as? NSWindow { onBecomeKey(key) }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
                if let key = note.object as? NSWindow { onResignKey(key) }
            }
    }
}
