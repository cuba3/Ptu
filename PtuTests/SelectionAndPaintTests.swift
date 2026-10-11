// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import XCTest
@testable import Ptu

final class SelectionAndPaintTests: XCTestCase {
    func testRectangleSelectionMatchesTheMarqueeClear() throws {
        let selection = PixelSelection.rectangle(CGRect(x: 2, y: 3, width: 4, height: 2), width: 10, height: 8)
        let coverage = try XCTUnwrap(selection).hardCoverage()
        XCTAssertEqual(coverage[3 * 10 + 2], 255)
        XCTAssertEqual(coverage[4 * 10 + 5], 255)
        XCTAssertEqual(coverage[2 * 10 + 2], 0)
        XCTAssertEqual(coverage[5 * 10 + 2], 0)
        XCTAssertTrue(try XCTUnwrap(selection).contains(CGPoint(x: 3.2, y: 3.2)))
        XCTAssertFalse(try XCTUnwrap(selection).contains(CGPoint(x: 1.2, y: 3.2)))
    }

    func testSelectionAddSubtractAndFeather() throws {
        let left = try XCTUnwrap(PixelSelection.rectangle(CGRect(x: 0, y: 0, width: 4, height: 4), width: 8, height: 4))
        let right = try XCTUnwrap(PixelSelection.rectangle(CGRect(x: 2, y: 0, width: 4, height: 4), width: 8, height: 4))
        let added = try XCTUnwrap(left.combining(right, mode: .add))
        XCTAssertEqual(added.hardCoverage()[1], 255)
        XCTAssertEqual(added.hardCoverage()[5], 255)
        let subtracted = try XCTUnwrap(added.combining(right, mode: .subtract))
        XCTAssertEqual(subtracted.hardCoverage()[1], 255)
        XCTAssertEqual(subtracted.hardCoverage()[3], 0)
        let soft = left.feathered(by: 3)
        let resolved = soft.resolvedCoverage()
        XCTAssertGreaterThan(resolved[1 * 8 + 1], 200)
        XCTAssertGreaterThan(resolved[1 * 8 + 4], 0)
        XCTAssertLessThan(resolved[1 * 8 + 4], 255)
    }

    func testMagicWandStaysInsideAContiguousBlob() throws {
        var buffer = PixelBuffer(width: 6, height: 4, fill: .white)
        buffer.setPixel(x: 1, y: 1, rgba: .red)
        buffer.setPixel(x: 2, y: 1, rgba: .red)
        buffer.setPixel(x: 2, y: 2, rgba: .red)
        buffer.setPixel(x: 5, y: 3, rgba: .red)
        let mask = try XCTUnwrap(MagicWand.mask(in: buffer, at: CGPoint(x: 1.2, y: 1.2), tolerance: 10, contiguous: true))
        XCTAssertEqual(mask[1 * 6 + 1], 255)
        XCTAssertEqual(mask[1 * 6 + 2], 255)
        XCTAssertEqual(mask[2 * 6 + 2], 255)
        XCTAssertEqual(mask[3 * 6 + 5], 0)
        let global = try XCTUnwrap(MagicWand.mask(in: buffer, at: CGPoint(x: 1.2, y: 1.2), tolerance: 10, contiguous: false))
        XCTAssertEqual(global[3 * 6 + 5], 255)
    }

    func testColorRangeSelectsMatchingPixels() {
        var buffer = PixelBuffer(width: 3, height: 1, fill: .white)
        buffer.setPixel(x: 0, y: 0, rgba: .red)
        buffer.setPixel(x: 1, y: 0, rgba: RGBA(r: 250, g: 8, b: 8, a: 255))
        buffer.setPixel(x: 2, y: 0, rgba: .blue)
        let mask = ColorRangeSelection.mask(in: buffer, include: [.red], exclude: [], fuzziness: 12, invert: false)
        XCTAssertEqual(mask[0], 255)
        XCTAssertEqual(mask[1], 255)
        XCTAssertEqual(mask[2], 0)
    }

    func testCloneStampCopiesAPixel() {
        var source = PixelBuffer(width: 8, height: 4, fill: .white)
        source.setPixel(x: 1, y: 1, rgba: .red)
        var destination = PixelBuffer(width: 8, height: 4, fill: .white)
        CloneStamp.dab(
            destination: &destination,
            destinationOrigin: .zero,
            source: source,
            sourceOrigin: .zero,
            center: CGPoint(x: 5.5, y: 1.5),
            offset: CGSize(width: -4, height: 0),
            radius: 0.6,
            hardness: 1,
            opacity: 1
        )
        XCTAssertEqual(destination.pixel(x: 5, y: 1), .red)
        XCTAssertEqual(destination.pixel(x: 0, y: 0), .white)
    }

    func testSpotHealReplacesASpotWithItsSurroundings() {
        var buffer = PixelBuffer(width: 16, height: 16, fill: .red)
        var coverage = [UInt8](repeating: 0, count: 16 * 16)
        for y in 7..<9 {
            for x in 7..<9 {
                buffer.setPixel(x: x, y: y, rgba: .blue)
                coverage[y * 16 + x] = 255
            }
        }
        XCTAssertTrue(SpotHeal.heal(buffer: &buffer, coverage: coverage, opacity: 1, mode: 0, seed: 7))
        let healed = buffer.pixel(x: 7, y: 7)
        XCTAssertGreaterThan(Int(healed.r), Int(healed.b))
    }

    func testSmudgeDragsColorForward() {
        var buffer = PixelBuffer(width: 12, height: 5, fill: .white)
        buffer.setPixel(x: 2, y: 2, rgba: .red)
        var carried = SmudgeBlur.pickUp(buffer: buffer, center: CGPoint(x: 2, y: 2), radius: 2)
        SmudgeBlur.smudge(
            buffer: &buffer,
            carried: &carried,
            center: CGPoint(x: 4, y: 2),
            diameter: 4,
            hardness: 1,
            strength: 1
        )
        XCTAssertGreaterThan(buffer.pixel(x: 4, y: 2).r, buffer.pixel(x: 4, y: 2).b)
    }

    func testGradientRunsFromDarkToLight() {
        var buffer = PixelBuffer(width: 8, height: 2, fill: .black)
        GradientRaster.paint(
            buffer: &buffer,
            originX: 0,
            originY: 0,
            kind: .linear,
            start: CGPoint(x: 0, y: 1),
            end: CGPoint(x: 8, y: 1),
            from: .black,
            to: .white,
            opacity: 1,
            coverage: nil,
            canvasWidth: 8
        )
        XCTAssertLessThan(buffer.pixel(x: 0, y: 0).r, buffer.pixel(x: 7, y: 0).r)
    }

    func testRectangleShapeFillsItsCenterAndEllipseLeavesTheCorner() throws {
        let shape = try XCTUnwrap(ShapeRaster.rectangle(CGRect(x: 2, y: 3, width: 6, height: 6), color: .red, cornerRadius: 0))
        XCTAssertEqual(shape.originX, 2)
        XCTAssertEqual(shape.originY, 3)
        XCTAssertEqual(shape.buffer.pixel(x: 3, y: 3), .red)
        let oval = try XCTUnwrap(ShapeRaster.ellipse(CGRect(x: 0, y: 0, width: 10, height: 10), color: .blue))
        XCTAssertGreaterThan(oval.buffer.pixel(x: 5, y: 5).a, 200)
        XCTAssertEqual(oval.buffer.pixel(x: 0, y: 0).a, 0)
    }

    func testContentFillCopiesTheSurroundingColor() {
        var buffer = PixelBuffer(width: 4, height: 4, fill: .red)
        buffer.setPixel(x: 1, y: 1, rgba: .blue)
        var mask = [UInt8](repeating: 0, count: 16)
        mask[1 * 4 + 1] = 255
        var bytes = buffer.copyBytes()
        XCTAssertTrue(ContentFill.fillBytes(&bytes, mask: mask, width: 4, height: 4))
        let filled = PixelBuffer(bytes: bytes, width: 4, height: 4)
        XCTAssertEqual(filled.pixel(x: 1, y: 1).r, 255)
        XCTAssertEqual(filled.pixel(x: 1, y: 1).b, 0)
    }

    func testObjectEdgeOffsetShrinksAMask() {
        var mask = [UInt8](repeating: 0, count: 25)
        for y in 1..<4 {
            for x in 1..<4 { mask[y * 5 + x] = 255 }
        }
        let eroded = ObjectSelection.adjusted(mask, width: 5, height: 5, edgeOffset: 1)
        XCTAssertEqual(eroded[2 * 5 + 2], 255)
        XCTAssertEqual(eroded[1 * 5 + 1], 0)
        XCTAssertLessThan(eroded.reduce(0) { $0 + Int($1) }, mask.reduce(0) { $0 + Int($1) })
    }

    func testMissingSubjectLeavesPixelsUntouched() {
        let source = PixelBuffer(width: 4, height: 4, fill: .white)
        let result = SubjectRemoval.removeBackground(from: source, detector: { _ in nil })
        guard case .noSubject = result else {
            return XCTFail("A missing subject mask must not invent pixels")
        }
    }

    func testSubjectPipelineKeepsTheProvidedMask() {
        let source = PixelBuffer(width: 8, height: 8, fill: .blue)
        let result = SubjectRemoval.removeBackground(from: source) { _ in
            var mask = [UInt8](repeating: 0, count: 64)
            for y in 0..<8 {
                for x in 0..<4 { mask[y * 8 + x] = 255 }
            }
            return mask
        }
        guard case .changed(let output) = result else {
            return XCTFail("A provided subject mask should remove the background")
        }
        XCTAssertGreaterThan(output.pixel(x: 1, y: 4).a, output.pixel(x: 6, y: 4).a)
    }

    func testClipboardCopiesSelectedPixels() throws {
        var buffer = PixelBuffer(width: 6, height: 4, fill: .clear)
        buffer.setPixel(x: 2, y: 1, rgba: .green)
        let layer = PixelLayer(
            id: UUID(),
            name: "Layer",
            isVisible: true,
            opacity: 1,
            blend: .normal,
            originX: 0,
            originY: 0,
            buffer: buffer
        )
        let selection = try XCTUnwrap(PixelSelection.rectangle(CGRect(x: 1, y: 0, width: 3, height: 3), width: 6, height: 4))
        let copied = try XCTUnwrap(SelectionClipboard.copy(layer: layer, selection: selection))
        XCTAssertEqual(copied.pixels.pixel(x: 1, y: 1), .green)
    }
}
