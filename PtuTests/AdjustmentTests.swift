// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import XCTest
@testable import Ptu

final class AdjustmentTests: XCTestCase {
    func testLevelsOutputWhiteZeroTurnsGrayBlack() {
        var settings = LevelsSettings()
        settings.ranges[0].outputWhite = 0
        let source = PixelBuffer(width: 1, height: 1, fill: RGBA(r: 180, g: 180, b: 180, a: 255))
        let pixel = settings.apply(source).pixel(x: 0, y: 0)
        XCTAssertEqual(pixel.r, 0)
        XCTAssertEqual(pixel.g, 0)
        XCTAssertEqual(pixel.b, 0)
        XCTAssertEqual(pixel.a, 255)
    }

    func testCurvesCanCrushWhiteToBlack() {
        var settings = CurvesSettings()
        settings.channels[0] = [CurvePoint(x: 0, y: 0), CurvePoint(x: 255, y: 0)]
        let source = PixelBuffer(width: 1, height: 1, fill: .white)
        XCTAssertEqual(settings.apply(source).pixel(x: 0, y: 0), .black)
    }

    func testMaskHidesTheLayerInTheComposite() throws {
        let white = PixelLayer(
            id: UUID(),
            name: "White",
            isVisible: true,
            opacity: 1,
            blend: .normal,
            originX: 0,
            originY: 0,
            buffer: PixelBuffer(width: 1, height: 1, fill: .white)
        )
        var red = PixelLayer(
            id: UUID(),
            name: "Red",
            isVisible: true,
            opacity: 1,
            blend: .normal,
            originX: 0,
            originY: 0,
            buffer: PixelBuffer(width: 1, height: 1, fill: .red)
        )
        red.mask = .filled(width: 1, height: 1, revealing: false)
        let model = DocumentModel(
            width: 1,
            height: 1,
            resolutionPPI: 72,
            layers: [.pixels(red), .pixels(white)],
            nextLayerNumber: 3,
            nextGroupNumber: 1
        )
        let pixel = try flattened(model).pixel(x: 0, y: 0)
        XCTAssertEqual(pixel, .white)
    }

    func testColorOverlayChangesTheComposite() throws {
        var overlay = ColorOverlayEffect()
        overlay.red = 0
        overlay.green = 0
        overlay.blue = 1
        overlay.opacity = 1
        var effects = LayerEffects()
        effects.colorOverlay = overlay
        let layer = PixelLayer(
            id: UUID(),
            name: "Red",
            isVisible: true,
            opacity: 1,
            blend: .normal,
            originX: 0,
            originY: 0,
            buffer: PixelBuffer(width: 1, height: 1, fill: .red),
            effects: effects
        )
        let model = DocumentModel(
            width: 1,
            height: 1,
            resolutionPPI: 72,
            layers: [.pixels(layer)],
            nextLayerNumber: 2,
            nextGroupNumber: 1
        )
        let pixel = try flattened(model).pixel(x: 0, y: 0)
        XCTAssertLessThan(pixel.r, 5)
        XCTAssertGreaterThan(pixel.b, 250)
    }

    func testInvertFilterTurnsWhiteBlack() {
        let source = PixelBuffer(width: 1, height: 1, fill: .white)
        let pixel = PixelFilter.apply(.invert, to: source, settings: FilterSettings()).pixel(x: 0, y: 0)
        XCTAssertEqual(pixel, .black)
    }

    func testPackageRoundTripKeepsMaskAdjustmentAndEffects() throws {
        var model = DocumentModel.blank(width: 2, height: 2, resolutionPPI: 72, background: .white)
        guard case .pixels(var layer) = model.layers[0] else {
            XCTFail("Expected a pixel layer")
            return
        }
        layer.mask = .filled(width: 2, height: 2, revealing: false)
        layer.mask?.buffer.setPixel(x: 0, y: 0, rgba: .white)
        var stroke = StrokeEffect()
        stroke.size = 3
        stroke.opacity = 0.5
        var effects = LayerEffects()
        effects.stroke = stroke
        layer.effects = effects
        model.layers[0] = .pixels(layer)
        let adjustmentID = model.addAdjustment(.levels, name: "Levels")
        var levels = LevelsSettings()
        levels.ranges[0].outputWhite = 10
        var adjustment = LayerAdjustment(kind: .levels)
        adjustment.levels = levels
        model.setAdjustment(id: adjustmentID, adjustment: adjustment)

        let wrapper = try ProjectStore.write(model)
        let loaded = try ProjectStore.read(wrapper: wrapper)
        guard case .adjustment(let adjustment) = loaded.layers[0],
              case .pixels(let pixels) = loaded.layers[1] else {
            XCTFail("Expected an adjustment layer in front of the pixel layer")
            return
        }
        XCTAssertEqual(adjustment.adjustment.kind, .levels)
        XCTAssertEqual(adjustment.adjustment.levels.ranges[0].outputWhite, 10)
        XCTAssertEqual(pixels.mask?.buffer.pixel(x: 0, y: 0).r, 255)
        XCTAssertEqual(pixels.mask?.buffer.pixel(x: 1, y: 1).r, 0)
        XCTAssertEqual(pixels.effects.stroke?.size, 3)
        XCTAssertEqual(pixels.effects.stroke?.opacity, 0.5)
    }

    func testLevelsAdjustmentLayerDarkensTheComposite() throws {
        let base = PixelLayer(
            id: UUID(),
            name: "Gray",
            isVisible: true,
            opacity: 1,
            blend: .normal,
            originX: 0,
            originY: 0,
            buffer: PixelBuffer(width: 1, height: 1, fill: RGBA(r: 200, g: 200, b: 200, a: 255))
        )
        var levels = LevelsSettings()
        levels.ranges[0].outputWhite = 0
        let adjustment = AdjustmentLayer(
            id: UUID(),
            name: "Levels",
            isVisible: true,
            opacity: 1,
            blend: .normal,
            adjustment: {
                var value = LayerAdjustment(kind: .levels)
                value.levels = levels
                return value
            }()
        )
        let model = DocumentModel(
            width: 1,
            height: 1,
            resolutionPPI: 72,
            layers: [.adjustment(adjustment), .pixels(base)],
            nextLayerNumber: 3,
            nextGroupNumber: 1
        )
        let pixel = try flattened(model).pixel(x: 0, y: 0)
        XCTAssertEqual(pixel.r, 0)
        XCTAssertEqual(pixel.a, 255)
    }

    private func flattened(_ model: DocumentModel) throws -> PixelBuffer {
        let image = try XCTUnwrap(Compositor.render(model))
        return try XCTUnwrap(PixelBuffer.from(cgImage: image))
    }
}
