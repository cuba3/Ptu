// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI
import XCTest
@testable import Ptu

@MainActor
final class SmokeTests: XCTestCase {
    func testNewBrushUndoSaveAndReopen() throws {
        let document = EditorDocumentSession(
            model: DocumentModel.blank(width: 32, height: 32, resolutionPPI: 72, background: .white)
        )
        let tools = ToolsViewModel(document: document)
        tools.tool = .brush
        document.foreground = .red
        tools.brushSize = 6
        tools.brushHardness = 1
        tools.brushOpacity = 1
        tools.mouseDown(at: CGPoint(x: 16, y: 16))
        tools.mouseUp(at: CGPoint(x: 16, y: 16))

        let layerID = try XCTUnwrap(document.selectedLayerID)
        let painted = try XCTUnwrap(document.model.pixelLayer(id: layerID)?.buffer.pixel(x: 16, y: 16))
        XCTAssertGreaterThan(painted.r, 200)
        XCTAssertLessThan(painted.g, 40)
        XCTAssertTrue(document.canUndo)

        document.undo()
        let restored = try XCTUnwrap(document.model.pixelLayer(id: layerID)?.buffer.pixel(x: 16, y: 16))
        XCTAssertEqual(restored, .white)
        XCTAssertTrue(document.canRedo)

        document.redo()
        let wrapper = try ProjectStore.write(document.model)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("ptu")
        try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try ProjectStore.read(wrapper: FileWrapper(url: url))
        let again = try XCTUnwrap(loaded.pixelLayer(id: layerID)?.buffer.pixel(x: 16, y: 16))
        XCTAssertGreaterThan(again.r, 200)
        XCTAssertLessThan(again.g, 40)
    }

    func testEditorViewCanBeHosted() {
        var document = PtuDocument()
        document.prefersSetupSheet = false
        let view = EditorView(document: .constant(document), fileURL: nil)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 1100, height: 720)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled, .resizable, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()
        XCTAssertFalse(host.frame.isEmpty)
    }
}
