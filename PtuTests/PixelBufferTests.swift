// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import XCTest
@testable import Ptu

final class PixelBufferTests: XCTestCase {
    func testCopyOnWriteKeepsTheOriginal() {
        let original = PixelBuffer(width: 2, height: 2, fill: .white)
        var copy = original
        XCTAssertTrue(original.sharesStorage(with: copy))
        copy.setPixel(x: 0, y: 0, rgba: .black)
        XCTAssertFalse(original.sharesStorage(with: copy))
        XCTAssertEqual(original.pixel(x: 0, y: 0), .white)
        XCTAssertEqual(copy.pixel(x: 0, y: 0), .black)
    }

    func testStampPaintsTheCenterAndLeavesTheCorner() {
        var buffer = PixelBuffer(width: 8, height: 8, fill: .clear)
        buffer.stamp(center: CGPoint(x: 4, y: 4), radius: 1.2, hardness: 1, opacity: 1, color: .red)
        XCTAssertEqual(buffer.pixel(x: 4, y: 4), .red)
        XCTAssertEqual(buffer.pixel(x: 0, y: 0), .clear)
    }

    func testPNGRoundTripKeepsTheTopLeftPixel() throws {
        var buffer = PixelBuffer(width: 2, height: 2, fill: .white)
        buffer.setPixel(x: 0, y: 0, rgba: .red)
        let image = try XCTUnwrap(buffer.cgImage())
        let data = try ImageFiles.pngData(from: image, ppi: 144)
        let decoded = try ImageFiles.decode(data)
        XCTAssertEqual(decoded.buffer.pixel(x: 0, y: 0), .red)
        XCTAssertEqual(decoded.buffer.pixel(x: 0, y: 1), .white)
        XCTAssertEqual(decoded.ppi, 144, accuracy: 0.5)
    }
}
