// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Metal
import XCTest
@testable import Ptu

final class GeometryTests: XCTestCase {
    func testFlipHorizontalReversesARow() {
        var buffer = PixelBuffer(width: 3, height: 1, fill: .clear)
        buffer.setPixel(x: 0, y: 0, rgba: .red)
        buffer.setPixel(x: 2, y: 0, rgba: .blue)
        let flipped = buffer.flippedHorizontally()
        XCTAssertEqual(flipped.pixel(x: 0, y: 0), .blue)
        XCTAssertEqual(flipped.pixel(x: 2, y: 0), .red)
        XCTAssertEqual(flipped.width, 3)
    }

    func testFlipLayerHorizontallySwapsATwoByOneRow() throws {
        var buffer = PixelBuffer(width: 2, height: 1, fill: .clear)
        buffer.setPixel(x: 0, y: 0, rgba: .red)
        buffer.setPixel(x: 1, y: 0, rgba: .blue)
        var model = DocumentModel.imported(buffer: buffer, resolutionPPI: 72, name: "row")
        let id = model.layers[0].id
        model.flipLayer(id: id, horizontally: true)
        let layer = try XCTUnwrap(model.pixelLayer(id: id))
        XCTAssertEqual(layer.buffer.pixel(x: 0, y: 0), .blue)
        XCTAssertEqual(layer.buffer.pixel(x: 1, y: 0), .red)
        XCTAssertEqual(layer.buffer.width, 2)
        XCTAssertEqual(layer.buffer.height, 1)

        model.flipLayer(id: id, horizontally: false)
        let vertical = try XCTUnwrap(model.pixelLayer(id: id))
        XCTAssertEqual(vertical.buffer.pixel(x: 0, y: 0), .blue)
        XCTAssertEqual(vertical.buffer.pixel(x: 1, y: 0), .red)
        XCTAssertEqual(vertical.buffer.height, 1)
    }

    func testTrimDropsTransparentEdges() {
        var buffer = PixelBuffer(width: 5, height: 4, fill: .clear)
        buffer.setPixel(x: 2, y: 1, rgba: .red)
        let rect = ImageTrim.bounds(in: buffer, options: TrimOptions())
        XCTAssertEqual(rect, CGRect(x: 2, y: 1, width: 1, height: 1))
    }

    func testCanvasResizeAnchorMovesTheLayer() {
        var model = DocumentModel.blank(width: 100, height: 50, background: .white)
        let shift = CanvasResize.offset(oldWidth: 100, oldHeight: 50, newWidth: 120, newHeight: 80, anchor: 4)
        XCTAssertEqual(shift.x, 10)
        XCTAssertEqual(shift.y, 15)
        model.resizeCanvas(toWidth: 120, height: 80, anchor: 4)
        XCTAssertEqual(model.width, 120)
        XCTAssertEqual(model.height, 80)
        let layer = model.pixelLayer(id: model.layers[0].id)
        XCTAssertEqual(layer?.originX, 10)
        XCTAssertEqual(layer?.originY, 15)
        XCTAssertEqual(layer?.buffer.width, 100)
        XCTAssertEqual(layer?.buffer.height, 50)
    }

    func testImageResizeChangesDocumentAndLayerDimensions() {
        var model = DocumentModel.blank(width: 20, height: 10, background: .white)
        model.resizeImage(toWidth: 10, height: 5, resolutionPPI: 144, sampling: .nearest)
        XCTAssertEqual(model.width, 10)
        XCTAssertEqual(model.height, 5)
        XCTAssertEqual(model.resolutionPPI, 144)
        let layer = model.pixelLayer(id: model.layers[0].id)
        XCTAssertEqual(layer?.buffer.width, 10)
        XCTAssertEqual(layer?.buffer.height, 5)
        XCTAssertEqual(layer?.originX, 0)
    }

    func testTileRectsCoverADirtyRegionOnTheGrid() {
        let small = CanvasTiles.rects(covering: CGRect(x: 10, y: 10, width: 20, height: 20), canvasWidth: 500, canvasHeight: 500)
        XCTAssertEqual(small, [CGRect(x: 0, y: 0, width: 256, height: 256)])
        let crossing = CanvasTiles.rects(covering: CGRect(x: 250, y: 250, width: 20, height: 20), canvasWidth: 500, canvasHeight: 500)
        XCTAssertEqual(crossing.count, 4)
        XCTAssertTrue(crossing.contains(CGRect(x: 0, y: 0, width: 256, height: 256)))
        XCTAssertTrue(crossing.contains(CGRect(x: 256, y: 256, width: 244, height: 244)))
    }

    func testGuideCoordinateConvertsAtNonUnitZoom() {
        let guide = CanvasGuide(id: UUID(), axis: .vertical, position: 10)
        let pan = CGPoint(x: 20, y: 4)
        let zoom: CGFloat = 2
        let viewX = guide.viewCoordinate(zoom: zoom, pan: pan)
        XCTAssertEqual(viewX, 40)
        let hit = GuideHit.nearest(
            guides: [guide],
            viewPoint: CGPoint(x: viewX + 1, y: 12),
            zoom: zoom,
            pan: pan,
            tolerance: 5
        )
        XCTAssertEqual(hit, guide)
    }

    func testGridSnapFollowsSpacingAndVisibility() {
        let grid = LayoutGrid(spacing: 50, subdivisions: 1)
        XCTAssertEqual(grid.snap(42, tolerance: 10, visible: true), 50)
        XCTAssertNil(grid.snap(42, tolerance: 10, visible: false))
        XCTAssertNil(grid.snap(20, tolerance: 5, visible: true))
    }

    func testGuideHitUsesViewSpace() {
        let guide = CanvasGuide(id: UUID(), axis: .vertical, position: 10)
        let hit = GuideHit.nearest(
            guides: [guide],
            viewPoint: CGPoint(x: 12, y: 40),
            zoom: 1,
            pan: .zero,
            tolerance: 5
        )
        XCTAssertEqual(hit, guide)
        let miss = GuideHit.nearest(
            guides: [guide],
            viewPoint: CGPoint(x: 40, y: 40),
            zoom: 1,
            pan: .zero,
            tolerance: 5
        )
        XCTAssertNil(miss)
    }

    func testRotateCanvasClockwiseMovesTheTopLeftPixel() throws {
        var model = DocumentModel.blank(width: 8, height: 4, background: .transparent)
        let id = model.layers[0].id
        model.update(id: id) { node in
            guard case .pixels(var layer) = node else { return }
            layer.buffer.setPixel(x: 0, y: 0, rgba: .red)
            node = .pixels(layer)
        }
        model.rotateCanvas(quarters: 1)
        XCTAssertEqual(model.width, 4)
        XCTAssertEqual(model.height, 8)
        let layer = try XCTUnwrap(model.pixelLayer(id: id))
        XCTAssertEqual(layer.buffer.pixel(x: 3, y: 0), .red)
        XCTAssertEqual(layer.originX, 0)
        XCTAssertEqual(layer.originY, 0)
    }

    func testMetalDisplayMatchesDeviceAvailability() {
        if MTLCreateSystemDefaultDevice() == nil {
            XCTAssertNil(MetalCanvasDisplay.shared)
        } else {
            XCTAssertNotNil(MetalCanvasDisplay.shared)
        }
    }
}
