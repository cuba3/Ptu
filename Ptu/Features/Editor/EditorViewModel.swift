// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
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
    let psdImport = PSDImportViewModel()
    let jpegExport = JPEGExportViewModel()
    let colorPicker = ColorPickerViewModel()
    let reloader = DocumentReloadController()

    var showExporter = false
    var exportItem: ExportedImage?
    var exportType: UTType = .png
    var exportError = false
    var adjustment: AdjustmentViewModel?
    var showRawImporter = false
    var showJPEGSheet = false
    var showsCanvasSize = false
    var showsImageSize = false
    var showsTrim = false
    var showsGridSettings = false
    var geometryMessage: String?
    var commandPalette: CommandPaletteViewModel?
    private(set) var fileURL: URL?
    var closeWindow: () -> Void = {}
    @ObservationIgnored weak var hostWindow: NSWindow?

    init(model: DocumentModel, needsSetup: Bool, importNotes: [PSDConversionNote] = []) {
        document = EditorDocumentSession(model: model)
        tools = ToolsViewModel(document: document)
        layers = LayersViewModel(document: document)
        inspector = InspectorViewModel(document: document)
        canvas = CanvasViewModel(document: document, tools: tools)
        self.needsSetup = needsSetup
        psdImport.onApply = { [weak self] model in
            self?.applyImported(model)
        }
        if !importNotes.isEmpty {
            psdImport.presentReport(importNotes)
        }
        inspector.onEditAdjustment = { [weak self] in
            self?.editSelectedAdjustment()
        }
        inspector.onPickColor = { [weak self] background in
            self?.beginColorPick(background: background)
        }
        reloader.currentModel = { [weak self] in
            self?.document.model ?? DocumentModel.blank()
        }
        reloader.onReload = { [weak self] model in
            self?.reload(model)
        }
    }

    var actions: EditorActions {
        EditorActions(
            canUndo: document.canUndo,
            canRedo: document.canRedo,
            undo: { [weak self] in _ = self?.perform(.undo) },
            redo: { [weak self] in _ = self?.perform(.redo) },
            deleteSelection: { [weak self] in _ = self?.perform(.deleteSelection) },
            hasSelection: tools.hasSelection,
            exportPNG: { [weak self] in _ = self?.perform(.exportPNG) },
            exportJPEG: { [weak self] in _ = self?.perform(.exportJPEG) },
            zoomIn: { [weak self] in _ = self?.perform(.zoomIn) },
            zoomOut: { [weak self] in _ = self?.perform(.zoomOut) },
            actualSize: { [weak self] in _ = self?.perform(.actualSize) },
            fit: { [weak self] in _ = self?.perform(.fit) },
            importPSD: { [weak self] in _ = self?.perform(.importPSD) },
            reload: { [weak self] in _ = self?.perform(.reload) },
            canReload: fileURL != nil,
            showCommandPalette: { [weak self] in self?.toggleCommandPalette() },
            showShortcuts: { ShortcutPanel.show() },
            canEditPixels: document.model.pixelLayer(id: document.selectedLayerID ?? UUID()) != nil,
            canMask: document.selectedLayerID != nil,
            hasMask: document.model.node(id: document.selectedLayerID ?? UUID())?.mask != nil,
            maskEnabled: document.model.node(id: document.selectedLayerID ?? UUID())?.mask?.isEnabled ?? false,
            editsMask: document.editsMask,
            performImage: { [weak self] command in self?.performImage(command) },
            selectAll: { [tools] in tools.selectAll() },
            deselect: { [tools] in tools.deselect() },
            inverseSelection: { [tools] in tools.inverseSelection() },
            featherSelection: { [tools] in tools.featherSelection() },
            copySelection: { [tools] in tools.copySelection() },
            cutSelection: { [tools] in tools.cutSelection() },
            pasteSelection: { [tools] in tools.pasteSelection() },
            floatSelection: { [tools] in tools.beginFloating() },
            contentAwareFill: { [tools] in tools.contentAwareFill() },
            selectSubject: { [tools] in tools.selectSubject() },
            removeBackground: { [tools] in tools.removeBackground() },
            canPaste: tools.canPaste,
            performGeometry: { [weak self] command in self?.performGeometry(command) },
            showsRulers: canvas.showsRulers,
            showsGuides: canvas.showsGuides,
            showsGrid: canvas.showsGrid,
            snapEnabled: canvas.snapEnabled,
            isTransforming: canvas.isTransforming,
            isEditingText: tools.isEditingText,
            deleteTypeCharacter: { [tools] in tools.deleteTypeCharacter() }
        )
    }

    func performImage(_ command: ImageCommand) {
        switch command {
        case .bake(let kind):
            presentAdjustment(kind, bake: true)
        case .invert:
            bakeInvert()
        case .developRaw:
            showRawImporter = true
        case .addMask:
            inspector.addMask(revealing: true)
        case .deleteMask:
            inspector.deleteMask()
        case .invertMask:
            inspector.invertMask()
        case .toggleMask:
            inspector.setMaskEnabled(!inspector.maskEnabled)
        case .editMask:
            document.editsMask.toggle()
        case .clippingMask:
            createClippingMask()
        case .releaseClipping:
            releaseClippingMask()
        case .newAdjustment(let kind):
            addAdjustmentLayer(kind)
        case .toggleEffect(let kind):
            inspector.toggleEffect(kind)
        }
    }

    func performGeometry(_ command: GeometryCommand) {
        switch command {
        case .freeTransform:
            beginFreeTransform(distort: false)
        case .distort:
            beginFreeTransform(distort: true)
        case .applyTransform:
            applyTransform()
        case .cancelTransform:
            canvas.clearTransform()
        case .flipHorizontal:
            flipSelection(horizontally: true)
        case .flipVertical:
            flipSelection(horizontally: false)
        case .flipCanvasHorizontal:
            flipCanvas(horizontally: true)
        case .flipCanvasVertical:
            flipCanvas(horizontally: false)
        case .rotateClockwise:
            rotateCanvas(quarters: 1)
        case .rotateCounterclockwise:
            rotateCanvas(quarters: -1)
        case .rotate180:
            rotateCanvas(quarters: 2)
        case .imageSize:
            showsImageSize = true
        case .canvasSize:
            showsCanvasSize = true
        case .trim:
            showsTrim = true
        case .toggleRulers:
            canvas.setShowsRulers(!canvas.showsRulers)
        case .toggleGuides:
            canvas.setShowsGuides(!canvas.showsGuides)
        case .toggleGrid:
            canvas.setShowsGrid(!canvas.showsGrid)
        case .toggleSnap:
            canvas.setSnapEnabled(!canvas.snapEnabled)
        case .gridSettings:
            showsGridSettings = true
        case .clearGuides:
            canvas.clearGuides()
        case .addHorizontalGuide:
            canvas.addGuide(axis: .horizontal)
        case .addVerticalGuide:
            canvas.addGuide(axis: .vertical)
        case .hand:
            tools.tool = .hand
        case .zoom:
            tools.tool = .zoom
        }
    }

    func applyCanvasSize(width: Int, height: Int, anchor: Int) {
        canvas.clearTransform()
        let shift = CanvasResize.offset(
            oldWidth: document.model.width,
            oldHeight: document.model.height,
            newWidth: width,
            newHeight: height,
            anchor: anchor
        )
        document.shiftCanvasOrigin(to: CGPoint(x: -CGFloat(shift.x), y: -CGFloat(shift.y)))
        document.edit(redraw: .full) { model in
            model.resizeCanvas(toWidth: width, height: height, anchor: anchor)
        }
        tools.selection = nil
        showsCanvasSize = false
    }

    func applyImageSize(width: Int, height: Int, resolutionPPI: Double, sampling: LayerSampling) {
        canvas.clearTransform()
        document.edit(redraw: .full) { model in
            model.resizeImage(toWidth: width, height: height, resolutionPPI: resolutionPPI, sampling: sampling)
        }
        tools.selection = nil
        canvas.requestZoom(.fit)
        showsImageSize = false
    }

    func applyTrim(_ options: TrimOptions) {
        guard let rect = document.model.trimRect(options: options) else {
            geometryMessage = L10n.Trim.empty
            showsTrim = false
            return
        }
        if Int(rect.minX) == 0, Int(rect.minY) == 0,
           Int(rect.width) == document.model.width, Int(rect.height) == document.model.height {
            geometryMessage = L10n.Trim.empty
            showsTrim = false
            return
        }
        canvas.clearTransform()
        document.shiftCanvasOrigin(to: CGPoint(x: rect.minX, y: rect.minY))
        document.edit(redraw: .full) { model in
            model.crop(to: rect)
        }
        tools.selection = nil
        showsTrim = false
    }

    private func beginFreeTransform(distort: Bool) {
        guard let id = document.selectedLayerID, let layer = document.model.pixelLayer(id: id) else { return }
        canvas.beginTransform(layer: layer, distort: distort)
    }

    private func applyTransform() {
        guard let baked = canvas.bakedTransform() else { return }
        canvas.clearTransform()
        document.edit(redraw: .full) { model in
            model.replaceLayerRaster(id: baked.id, buffer: baked.buffer, originX: baked.originX, originY: baked.originY)
        }
    }

    private func flipSelection(horizontally: Bool) {
        if canvas.flipDraft(horizontally: horizontally) { return }
        guard let id = document.selectedLayerID else { return }
        document.edit(redraw: .full) { model in
            model.flipLayer(id: id, horizontally: horizontally)
        }
    }

    private func flipCanvas(horizontally: Bool) {
        canvas.clearTransform()
        document.edit(redraw: .full) { model in
            model.flipCanvas(horizontally: horizontally)
        }
        tools.selection = nil
    }

    private func rotateCanvas(quarters: Int) {
        canvas.clearTransform()
        document.edit(redraw: .full) { model in
            model.rotateCanvas(quarters: quarters)
        }
        tools.selection = nil
        canvas.requestZoom(.fit)
    }

    func presentRaw(_ url: URL) {
        adjustment = AdjustmentViewModel(
            kind: .rawDevelop,
            document: document,
            bakeLayerID: nil,
            adjustmentLayerID: nil,
            rawURL: url,
            rawSettings: RawImporter.asShot(url) ?? RawDevelopSettings()
        )
    }

    func bind(onModelChange: @escaping (DocumentModel) -> Void) {
        document.onModelChange = onModelChange
    }

    func attach(window: NSWindow) {
        hostWindow = window
        closeWindow = { [weak window] in window?.close() }
    }

    func watchFile(_ url: URL?) {
        fileURL = url
        reloader.isEdited = { [weak self] in
            guard let window = self?.hostWindow,
                  let document = NSDocumentController.shared.document(for: window) else { return false }
            return document.isDocumentEdited
        }
        reloader.watch(url)
    }

    func adoptExternal(_ model: DocumentModel) {
        guard !document.isCoalescing, model != document.model else { return }
        let selected = document.selectedLayerID
        document.replaceDocument(model)
        if let selected, model.node(id: selected) != nil {
            document.selectedLayerID = selected
        }
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

    func confirmJPEGExport() {
        do {
            jpegExport.rememberQuality()
            let data = try jpegExport.encodedData()
            exportItem = ExportedImage(data: data)
            exportType = .jpeg
            showJPEGSheet = false
            DispatchQueue.main.async { [weak self] in
                self?.showExporter = true
            }
        } catch {
            exportError = true
        }
    }

    func toggleCommandPalette() {
        if commandPalette != nil {
            commandPalette = nil
        } else {
            commandPalette = CommandPaletteViewModel(entries: paletteEntries())
        }
    }

    @discardableResult
    func perform(_ id: EditorCommandID) -> Bool {
        switch id {
        case .undo:
            guard document.canUndo else { return false }
            document.undo()
        case .redo:
            guard document.canRedo else { return false }
            document.redo()
        case .exportPNG:
            exportPNG()
        case .exportJPEG:
            exportJPEG()
        case .importPSD:
            psdImport.isChoosingFile = true
        case .reload:
            guard fileURL != nil else { return false }
            reloader.requestManual()
        case .commandPalette:
            toggleCommandPalette()
        case .zoomIn:
            canvas.requestZoom(.zoomIn)
        case .zoomOut:
            canvas.requestZoom(.zoomOut)
        case .actualSize:
            canvas.requestZoom(.actualSize)
        case .fit:
            canvas.requestZoom(.fit)
        case .deleteSelection:
            guard tools.selection != nil else { return false }
            tools.deleteSelection()
        case .swapColors:
            document.swapColors()
        case .resetColors:
            document.foreground = .black
            document.background = .white
        case .toolMove:
            tools.tool = .move
        case .toolMarquee:
            tools.tool = .marquee
        case .toolBrush:
            tools.tool = .brush
        case .toolCrop:
            tools.tool = .crop
        case .toolEyedropper:
            tools.tool = .eyedropper
        case .newLayer:
            layers.addLayer()
        case .newGroup:
            layers.addGroup()
        case .duplicateLayer:
            guard document.selectedLayerID != nil else { return false }
            layers.duplicateSelected()
        case .deleteLayer:
            guard document.selectedLayerID != nil else { return false }
            layers.deleteSelected()
        case .bringForward:
            guard document.selectedLayerID != nil else { return false }
            layers.bringForward()
        case .sendBackward:
            guard document.selectedLayerID != nil else { return false }
            layers.sendBackward()
        }
        return true
    }

    private func applyImported(_ model: DocumentModel) {
        tools.resetForNewCanvas()
        canvas.requestZoom(.fit)
        needsSetup = false
        document.replaceDocument(model)
    }

    private func reload(_ model: DocumentModel) {
        let selected = document.selectedLayerID
        let foreground = document.foreground
        let background = document.background
        document.replaceDocument(model)
        document.foreground = foreground
        document.background = background
        if let selected, model.node(id: selected) != nil {
            document.selectedLayerID = selected
        }
    }

    private func beginColorPick(background: Bool) {
        let current = background ? document.background : document.foreground
        colorPicker.begin(color: current, background: background) { [weak self] color, background in
            guard let self else { return }
            if background {
                self.document.background = color
            } else {
                self.document.foreground = color
            }
        }
    }

    private func exportPNG() {
        guard let image = Compositor.render(document.model) else {
            exportError = true
            return
        }
        do {
            exportItem = ExportedImage(data: try ImageFiles.pngData(from: image, ppi: document.model.resolutionPPI))
            exportType = .png
            showExporter = true
        } catch {
            exportError = true
        }
    }

    private func exportJPEG() {
        guard let image = Compositor.render(document.model) else {
            exportError = true
            return
        }
        jpegExport.configure(image: image, ppi: document.model.resolutionPPI)
        showJPEGSheet = true
    }

    private func paletteEntries() -> [CommandPaletteEntry] {
        var entries: [CommandPaletteEntry] = []
        func add(_ id: EditorCommandID, enabled: Bool = true) {
            entries.append(CommandPaletteEntry(
                id: id.rawValue,
                title: id.title,
                shortcut: ShortcutStore.shared.chord(for: id).label,
                isEnabled: enabled
            ) { [weak self] in
                self?.runPalette(id)
            })
        }
        add(.undo, enabled: document.canUndo)
        add(.redo, enabled: document.canRedo)
        add(.exportPNG)
        add(.exportJPEG)
        add(.importPSD)
        add(.reload, enabled: fileURL != nil)
        add(.zoomIn)
        add(.zoomOut)
        add(.actualSize)
        add(.fit)
        add(.deleteSelection, enabled: tools.selection != nil)
        add(.newLayer)
        add(.newGroup)
        let hasLayer = document.selectedLayerID != nil
        add(.duplicateLayer, enabled: hasLayer)
        add(.deleteLayer, enabled: hasLayer)
        add(.bringForward, enabled: hasLayer)
        add(.sendBackward, enabled: hasLayer)
        add(.swapColors)
        add(.resetColors)
        add(.toolMove)
        add(.toolMarquee)
        add(.toolBrush)
        add(.toolCrop)
        add(.toolEyedropper)
        entries.append(CommandPaletteEntry(
            id: "document.new",
            title: L10n.Tabs.new,
            shortcut: "⌘N",
            isEnabled: true
        ) { [weak self] in
            self?.commandPalette = nil
            NSDocumentController.shared.newDocument(nil)
        })
        entries.append(CommandPaletteEntry(
            id: "document.open",
            title: L10n.Menu.open,
            shortcut: "⌘O",
            isEnabled: true
        ) { [weak self] in
            self?.commandPalette = nil
            NSDocumentController.shared.openDocument(nil)
        })
        entries.append(CommandPaletteEntry(
            id: "document.close",
            title: L10n.Tabs.close,
            shortcut: "⌘W",
            isEnabled: true
        ) { [weak self] in
            self?.commandPalette = nil
            self?.closeWindow()
        })
        for url in RecentFiles.shared.urls {
            entries.append(CommandPaletteEntry(
                id: "recent.\(url.path)",
                title: L10n.Command.openRecent(url.lastPathComponent),
                shortcut: nil,
                isEnabled: true
            ) { [weak self] in
                self?.commandPalette = nil
                RecentFiles.shared.open(url)
            })
        }
        return entries
    }

    private func presentAdjustment(_ kind: AdjustmentSheetKind, bake: Bool) {
        let pixelID = document.model.pixelLayer(id: document.selectedLayerID ?? UUID())?.id
        guard !bake || pixelID != nil else { return }
        adjustment = AdjustmentViewModel(
            kind: kind,
            document: document,
            bakeLayerID: bake ? pixelID : nil,
            adjustmentLayerID: nil,
            rawURL: nil,
            rawSettings: nil
        )
    }

    private func editSelectedAdjustment() {
        guard let id = document.selectedLayerID, case .adjustment(let layer) = document.model.node(id: id) else { return }
        guard let kind = sheetKind(layer.adjustment.kind) else { return }
        adjustment = AdjustmentViewModel(
            kind: kind,
            document: document,
            bakeLayerID: nil,
            adjustmentLayerID: id,
            rawURL: nil,
            rawSettings: nil
        )
    }

    private func bakeInvert() {
        guard let id = document.selectedLayerID, let layer = document.model.pixelLayer(id: id) else { return }
        let inverted = InvertAdjustment.apply(layer.buffer)
        document.edit(redraw: .full) { model in
            model.replacePixels(id: id, buffer: inverted)
        }
    }

    private func addAdjustmentLayer(_ kind: AdjustmentKind) {
        var created: UUID?
        document.edit(redraw: .full) { model in
            created = model.addAdjustment(kind, name: kind.title)
        }
        guard let created else { return }
        document.selectedLayerID = created
        guard let sheet = sheetKind(kind) else { return }
        adjustment = AdjustmentViewModel(
            kind: sheet,
            document: document,
            bakeLayerID: nil,
            adjustmentLayerID: created,
            rawURL: nil,
            rawSettings: nil
        )
    }

    private func createClippingMask() {
        guard let id = document.selectedLayerID, let below = document.model.layerBelow(id), document.model.pixelLayer(id: below.id) != nil else { return }
        document.edit(redraw: .full) { model in
            _ = model.linkClippingMask(target: id, source: below.id)
        }
    }

    private func releaseClippingMask() {
        guard let id = document.selectedLayerID else { return }
        document.edit(redraw: .full) { model in
            model.releaseClippingMask(target: id)
        }
    }

    private func sheetKind(_ kind: AdjustmentKind) -> AdjustmentSheetKind? {
        switch kind {
        case .levels: .levels
        case .curves: .curves
        case .hueSaturation: .hueSaturation
        case .exposure: .exposure
        case .blackWhite: .blackWhite
        case .colorBalance: .colorBalance
        case .gradientMap: .gradientMap
        case .grain: .grain
        case .gaussianBlur: .gaussianBlur
        case .motionBlur: .motionBlur
        case .addNoise: .addNoise
        case .vignette: .vignette
        case .bloomGlow: .bloomGlow
        case .tonalContrast: .tonalContrast
        case .dither: .dither
        case .cameraRaw: .cameraRaw
        case .invert: nil
        }
    }

    private func runPalette(_ id: EditorCommandID) {
        commandPalette = nil
        if id != .commandPalette {
            _ = perform(id)
        }
    }
}
