// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import XCTest
@testable import Ptu

final class CompositorTests: XCTestCase {
    func testTopLeftPixelStaysAtTheTopLeft() throws {
        var model = DocumentModel.blank(width: 2, height: 2, resolutionPPI: 72, background: .white)
        if case .pixels(var layer) = model.layers[0] {
            layer.buffer.setPixel(x: 0, y: 0, rgba: .red)
            model.layers[0] = .pixels(layer)
        }
        let image = try XCTUnwrap(Compositor.render(model))
        let buffer = try XCTUnwrap(PixelBuffer.from(cgImage: image))
        XCTAssertEqual(buffer.pixel(x: 0, y: 0), .red)
        XCTAssertEqual(buffer.pixel(x: 1, y: 1), .white)
    }

    func testMultiplyBlueOverRedIsBlack() throws {
        let red = PixelLayer(
            id: UUID(),
            name: "Red",
            isVisible: true,
            opacity: 1,
            blend: .normal,
            originX: 0,
            originY: 0,
            buffer: PixelBuffer(width: 1, height: 1, fill: .red)
        )
        let blue = PixelLayer(
            id: UUID(),
            name: "Blue",
            isVisible: true,
            opacity: 1,
            blend: .multiply,
            originX: 0,
            originY: 0,
            buffer: PixelBuffer(width: 1, height: 1, fill: .blue)
        )
        let model = DocumentModel(
            width: 1,
            height: 1,
            resolutionPPI: 72,
            layers: [.pixels(blue), .pixels(red)],
            nextLayerNumber: 3,
            nextGroupNumber: 1
        )
        let buffer = try flattened(model)
        let pixel = buffer.pixel(x: 0, y: 0)
        XCTAssertLessThanOrEqual(pixel.r, 1)
        XCTAssertLessThanOrEqual(pixel.g, 1)
        XCTAssertLessThanOrEqual(pixel.b, 1)
    }

    func testHalfRedOverWhite() throws {
        let white = opaqueLayer(fill: .white, blend: .normal, opacity: 1)
        let red = opaqueLayer(fill: .red, blend: .normal, opacity: 0.5)
        let model = document(layers: [.pixels(red), .pixels(white)])
        let pixel = try flattened(model).pixel(x: 0, y: 0)
        XCTAssertGreaterThanOrEqual(pixel.r, 250)
        XCTAssertGreaterThanOrEqual(pixel.g, 120)
        XCTAssertLessThanOrEqual(pixel.g, 135)
        XCTAssertGreaterThanOrEqual(pixel.b, 120)
        XCTAssertLessThanOrEqual(pixel.b, 135)
    }

    func testGroupOpacityBlendsTheFlattenedGroup() throws {
        let child = opaqueLayer(fill: .red, blend: .normal, opacity: 1)
        let group = GroupLayer(
            id: UUID(),
            name: "Group",
            isVisible: true,
            opacity: 0.5,
            blend: .normal,
            children: [.pixels(child)]
        )
        let white = opaqueLayer(fill: .white, blend: .normal, opacity: 1)
        let model = document(layers: [.group(group), .pixels(white)])
        let pixel = try flattened(model).pixel(x: 0, y: 0)
        XCTAssertGreaterThanOrEqual(pixel.r, 250)
        XCTAssertGreaterThanOrEqual(pixel.g, 120)
        XCTAssertLessThanOrEqual(pixel.g, 135)
    }

    func testMovingFrontLayerBackwardRevealsTheLayerBelow() throws {
        let red = opaqueLayer(fill: .red, blend: .normal, opacity: 1)
        let blue = opaqueLayer(fill: .blue, blend: .normal, opacity: 1)
        var model = document(layers: [.pixels(blue), .pixels(red)])
        model.move(id: blue.id, towardFront: false)
        let pixel = try flattened(model).pixel(x: 0, y: 0)
        XCTAssertGreaterThan(pixel.r, 250)
        XCTAssertLessThan(pixel.b, 5)
    }

    private func opaqueLayer(fill: RGBA, blend: BlendMode, opacity: Double) -> PixelLayer {
        PixelLayer(
            id: UUID(),
            name: "Layer",
            isVisible: true,
            opacity: opacity,
            blend: blend,
            originX: 0,
            originY: 0,
            buffer: PixelBuffer(width: 1, height: 1, fill: fill)
        )
    }

    private func document(layers: [LayerNode]) -> DocumentModel {
        DocumentModel(
            width: 1,
            height: 1,
            resolutionPPI: 72,
            layers: layers,
            nextLayerNumber: 3,
            nextGroupNumber: 2
        )
    }

    private func flattened(_ model: DocumentModel) throws -> PixelBuffer {
        let image = try XCTUnwrap(Compositor.render(model))
        return try XCTUnwrap(PixelBuffer.from(cgImage: image))
    }
}
