// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import XCTest
@testable import Ptu

final class HistoryTests: XCTestCase {
    func testUndoSnapshotSharesUntouchedLayerStorage() {
        var model = DocumentModel.blank(width: 4, height: 4, resolutionPPI: 72, background: .white)
        _ = model.addPixelLayer()
        var history = DocumentHistory()
        history.push(model)
        guard case .pixels(var front) = model.layers[0] else {
            XCTFail("Expected a pixel layer")
            return
        }
        front.buffer.setPixel(x: 0, y: 0, rgba: .red)
        model.layers[0] = .pixels(front)

        guard case .pixels(let storedFront) = history.undoStack[0].layers[0],
              case .pixels(let currentFront) = model.layers[0],
              case .pixels(let storedBack) = history.undoStack[0].layers[1],
              case .pixels(let currentBack) = model.layers[1] else {
            XCTFail("Expected two pixel layers")
            return
        }
        XCTAssertFalse(storedFront.buffer.sharesStorage(with: currentFront.buffer))
        XCTAssertTrue(storedBack.buffer.sharesStorage(with: currentBack.buffer))
        XCTAssertEqual(storedFront.buffer.pixel(x: 0, y: 0), .clear)
        XCTAssertEqual(currentFront.buffer.pixel(x: 0, y: 0), .red)
    }

    func testLimitDropsTheOldestEntry() {
        var history = DocumentHistory()
        for index in 0..<60 {
            var model = DocumentModel.blank(width: 1, height: 1, resolutionPPI: 72, background: .white)
            model.nextLayerNumber = index
            history.push(model)
        }
        XCTAssertEqual(history.undoStack.count, DocumentHistory.limit)
        XCTAssertEqual(history.undoStack[0].nextLayerNumber, 10)
    }
}
