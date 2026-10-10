// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import XCTest
@testable import Ptu

@MainActor
final class CropAndBrushTests: XCTestCase {
    func testCropCopiesThePixelsInsteadOfResizingThePicture() throws {
        var model = paintedCanvas()
        model.crop(to: CGRect(x: 10, y: 20, width: 5, height: 5))
        XCTAssertEqual(model.width, 5)
        XCTAssertEqual(model.height, 5)
        let layer = try XCTUnwrap(model.pixelLayer(id: model.layers[0].id))
        XCTAssertEqual(layer.buffer.width, 5)
        XCTAssertEqual(layer.buffer.height, 5)
        XCTAssertEqual(layer.buffer.pixel(x: 0, y: 0), .red)
        XCTAssertEqual(layer.buffer.pixel(x: 4, y: 4), .blue)
        XCTAssertEqual(layer.originX, 0)
        XCTAssertEqual(layer.originY, 0)
    }

    func testFractionalCropUsesTheOuterPixelEdges() throws {
        var model = paintedCanvas()
        model.crop(to: CGRect(x: 9.2, y: 19.2, width: 5.1, height: 5.1))
        XCTAssertEqual(model.width, 6)
        XCTAssertEqual(model.height, 6)
        let layer = try XCTUnwrap(model.pixelLayer(id: model.layers[0].id))
        XCTAssertEqual(layer.buffer.pixel(x: 1, y: 1), .red)
    }

    func testBrushStrokePublishesOnceAndUndoesAsOneEdit() throws {
        let document = EditorDocumentSession(
            model: DocumentModel.blank(width: 32, height: 32, background: .transparent)
        )
        let tools = ToolsViewModel(document: document)
        tools.tool = .brush
        var publishes = 0
        document.onModelChange = { _ in publishes += 1 }
        tools.mouseDown(at: CGPoint(x: 4, y: 4))
        tools.mouseDragged(to: CGPoint(x: 20, y: 4))
        XCTAssertEqual(publishes, 0)
        XCTAssertFalse(document.canUndo)
        XCTAssertEqual(document.model.pixelLayer(id: document.model.layers[0].id)?.buffer.pixel(x: 4, y: 4).a, 0)
        XCTAssertGreaterThan(document.canvasModel().pixelLayer(id: document.model.layers[0].id)?.buffer.pixel(x: 4, y: 4).a ?? 0, 0)
        tools.mouseUp(at: CGPoint(x: 20, y: 4))
        XCTAssertEqual(publishes, 1)
        XCTAssertTrue(document.canUndo)
        XCTAssertGreaterThan(document.model.pixelLayer(id: document.model.layers[0].id)?.buffer.pixel(x: 8, y: 4).a ?? 0, 0)
        document.undo()
        XCTAssertEqual(document.model.pixelLayer(id: document.model.layers[0].id)?.buffer.pixel(x: 8, y: 4).a, 0)
    }

    private func paintedCanvas() -> DocumentModel {
        var model = DocumentModel.blank(width: 30, height: 40, background: .white)
        if case .pixels(var layer) = model.layers[0] {
            layer.buffer.setPixel(x: 0, y: 0, rgba: .green)
            layer.buffer.setPixel(x: 10, y: 20, rgba: .red)
            layer.buffer.setPixel(x: 14, y: 24, rgba: .blue)
            model.layers[0] = .pixels(layer)
        }
        return model
    }
}
