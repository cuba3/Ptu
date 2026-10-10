// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import XCTest
@testable import Ptu

final class ProjectStoreTests: XCTestCase {
    func testRoundTripPreservesLayersBlendAndPixels() throws {
        var model = DocumentModel.blank(width: 3, height: 2, resolutionPPI: 150, background: .white)
        let groupID = model.addGroup()
        if case .pixels(var layer) = model.layers[1] {
            layer.buffer.setPixel(x: 1, y: 0, rgba: .red)
            layer.opacity = 0.4
            layer.blend = .multiply
            layer.originX = 1
            model.layers[1] = .pixels(layer)
        }
        _ = groupID

        let wrapper = try ProjectStore.write(model)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("ptu")
        try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try ProjectStore.read(wrapper: FileWrapper(url: url))
        XCTAssertEqual(loaded.width, 3)
        XCTAssertEqual(loaded.height, 2)
        XCTAssertEqual(loaded.resolutionPPI, 150)
        XCTAssertEqual(loaded.layers.count, model.layers.count)
        guard case .group = loaded.layers[0], case .pixels(let pixels) = loaded.layers[1] else {
            XCTFail("Expected a group in front of a pixel layer")
            return
        }
        XCTAssertEqual(pixels.blend, .multiply)
        XCTAssertEqual(pixels.opacity, 0.4)
        XCTAssertEqual(pixels.originX, 1)
        XCTAssertEqual(pixels.buffer.pixel(x: 1, y: 0), .red)
        XCTAssertEqual(pixels.buffer.pixel(x: 0, y: 1), .white)
    }

    func testUnsupportedVersionIsRejected() throws {
        let json = """
        {"formatVersion":99,"height":1,"layers":[],"nextGroupNumber":1,"nextLayerNumber":1,"resolutionPPI":72,"width":1}
        """
        let root = FileWrapper(directoryWithFileWrappers: [:])
        let manifest = FileWrapper(regularFileWithContents: Data(json.utf8))
        manifest.preferredFilename = "manifest.json"
        root.addFileWrapper(manifest)
        let layers = FileWrapper(directoryWithFileWrappers: [:])
        layers.preferredFilename = "layers"
        root.addFileWrapper(layers)
        XCTAssertThrowsError(try ProjectStore.read(wrapper: root)) { error in
            XCTAssertEqual(error as? DocumentError, .unsupportedVersion)
        }
    }
}
