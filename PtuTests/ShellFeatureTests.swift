// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import XCTest
@testable import Ptu

final class ShellFeatureTests: XCTestCase {
    func testRecentFileListPutsTheNewestFirstAndCapsTheLength() {
        let older = URL(fileURLWithPath: "/tmp/older.ptu")
        let newer = URL(fileURLWithPath: "/tmp/newer.ptu")
        var urls = RecentFileList.note(older, into: [])
        urls = RecentFileList.note(newer, into: urls)
        urls = RecentFileList.note(older, into: urls)
        XCTAssertEqual(urls.map(\.lastPathComponent), ["older.ptu", "newer.ptu"])

        for index in 0..<14 {
            urls = RecentFileList.note(URL(fileURLWithPath: "/tmp/file-\(index).ptu"), into: urls)
        }
        XCTAssertEqual(urls.count, RecentFileList.limit)
        XCTAssertEqual(urls.first?.lastPathComponent, "file-13.ptu")
        XCTAssertFalse(urls.contains { $0.lastPathComponent == "older.ptu" })
    }

    func testRecentFileListDropsMissingFiles() {
        let kept = URL(fileURLWithPath: "/tmp/kept.ptu")
        let missing = URL(fileURLWithPath: "/tmp/missing.ptu")
        let filtered = RecentFileList.removingMissing([kept, missing]) { $0.lastPathComponent == "kept.ptu" }
        XCTAssertEqual(filtered, [kept])
    }

    func testJPEGQualityChangesEncodedSize() throws {
        var buffer = PixelBuffer(width: 48, height: 48, fill: .white)
        for y in 0..<48 {
            for x in 0..<48 {
                let shade = UInt8((x * 5 + y * 3) % 256)
                buffer.setPixel(x: x, y: y, rgba: RGBA(r: shade, g: UInt8(255 - shade), b: UInt8((x * y) % 256), a: 255))
            }
        }
        let image = try XCTUnwrap(buffer.cgImage())
        let low = try ImageFiles.jpegData(from: image, ppi: 72, quality: 0.05)
        let high = try ImageFiles.jpegData(from: image, ppi: 72, quality: 1)
        XCTAssertGreaterThan(low.count, 0)
        XCTAssertLessThan(low.count, high.count)
    }

    func testPSDImportKeepsPixelsGroupsVisibilityOpacityAndBlend() throws {
        let data = PSDFixture.file(
            width: 2,
            height: 2,
            resolutionPPI: 144,
            layers: [
                PSDFixture.Layer(name: "bnd", top: 0, left: 0, bottom: 0, right: 0, section: 3),
                PSDFixture.Layer(
                    name: "Dot",
                    top: 0, left: 0, bottom: 1, right: 1,
                    opacity: 128,
                    blend: "mul ",
                    planes: [(-1, [255]), (0, [255]), (1, [0]), (2, [0])]
                ),
                PSDFixture.Layer(name: "Grp", top: 0, left: 0, bottom: 0, right: 0, blend: "pass", section: 1),
            ]
        )
        let imported = try PSDImporter.read(data)
        XCTAssertEqual(imported.model.width, 2)
        XCTAssertEqual(imported.model.height, 2)
        XCTAssertEqual(imported.model.resolutionPPI, 144)
        guard case .group(let group) = imported.model.layers.first else {
            return XCTFail("Expected a group")
        }
        XCTAssertEqual(group.name, "Grp")
        XCTAssertEqual(group.blend, .normal)
        XCTAssertEqual(group.children.count, 1)
        guard case .pixels(let layer) = group.children.first else {
            return XCTFail("Expected a pixel layer")
        }
        XCTAssertEqual(layer.name, "Dot")
        XCTAssertTrue(layer.isVisible)
        XCTAssertEqual(layer.blend, .multiply)
        XCTAssertEqual(layer.opacity, 128.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(layer.buffer.pixel(x: 0, y: 0), .red)
        XCTAssertTrue(imported.notes.contains { $0.layerName == "Grp" && $0.message == L10n.PSD.groupPass })
    }

    func testPSDRejectsTheWrongDepth() {
        var data = Data("8BPS".utf8)
        data.append(contentsOf: [0, 1, 0, 0, 0, 0, 0, 0, 0, 3])
        data.append(contentsOf: [0, 0, 0, 1, 0, 0, 0, 1, 0, 16, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertThrowsError(try PSDReader.read(data)) { error in
            XCTAssertEqual(error as? PSDError, .unsupportedDepth)
        }
    }

    @MainActor
    func testBlendModeMappingAndShortcutConflicts() {
        XCTAssertEqual(BlendMode.fromPSD("scrn"), .screen)
        XCTAssertNil(BlendMode.fromPSD("hue "))
        XCTAssertNil(ShortcutStore.problem(in: [:]))
        let conflict = ShortcutStore.problem(in: [
            EditorCommandID.exportPNG.rawValue: EditorCommandID.undo.defaultChord,
        ])
        XCTAssertNotNil(conflict)
    }

    func testToolShortcutIsIgnoredWhileEditingText() {
        XCTAssertEqual(EditorCommandID.toolEyedropper.defaultChord.key, "i")
        XCTAssertFalse(EditorCommandID.swapColors.isMenu)
        XCTAssertFalse(EditorCommandID.resetColors.isMenu)
        for command in EditorCommandID.allCases {
            for modifiers in [0, 1, 2, 8, 9] {
                XCTAssertFalse(
                    TextEditingGate.allowsCanvasCommand(command, modifiers: modifiers, isEditingText: true),
                    "\(command.rawValue) should be blocked while editing"
                )
            }
            XCTAssertTrue(
                TextEditingGate.allowsCanvasCommand(command, modifiers: command.defaultChord.modifiers, isEditingText: false)
            )
        }
        XCTAssertFalse(TextEditingGate.allowsCanvasCommand(.swapColors, modifiers: 0, isEditingText: true))
        XCTAssertFalse(TextEditingGate.allowsCanvasCommand(.newLayer, modifiers: 9, isEditingText: true))
        XCTAssertFalse(TextEditingGate.allowsCanvasCommand(.toolEyedropper, modifiers: 0, isEditingText: true))
        XCTAssertNil(TextEditingGate.shelfTool(for: "i", isEditingText: true))
        XCTAssertNil(TextEditingGate.shelfTool(for: "v", isEditingText: true))
        XCTAssertEqual(TextEditingGate.shelfTool(for: "i", isEditingText: false), .eyedropper)
        XCTAssertEqual(TextEditingGate.shelfTool(for: "v", isEditingText: false), .move)
        XCTAssertEqual(TextEditingGate.shelfTool(for: "b", isEditingText: false), .brush)
    }

    func testCommandSearchPrefersAWordStart() {
        let entries = [
            CommandPaletteEntry(id: "export", title: "Export JPEG", shortcut: nil, isEnabled: true, perform: {}),
            CommandPaletteEntry(id: "redo", title: "Redo", shortcut: nil, isEnabled: true, perform: {}),
        ]
        let ranked = CommandPaletteSearch.rank(entries, query: "exp")
        XCTAssertEqual(ranked.first?.id, "export")
        XCTAssertNil(CommandPaletteSearch.score("zzz", in: "Export JPEG"))
    }

    func testTabOverflowKeepsTheSelectedTabVisible() {
        let ids = [UUID(), UUID(), UUID()]
        let widths = Dictionary(uniqueKeysWithValues: ids.map { ($0, CGFloat(100)) })
        let layout = DocumentTabLayout.overflow(
            order: ids,
            widths: widths,
            selectedID: ids[0],
            availableWidth: 160,
            pillWidth: { _ in 40 }
        )
        XCTAssertTrue(layout.visible.contains { $0.id == ids[0] })
        XCTAssertFalse(layout.hiddenIDs.contains(ids[0]))
        XCTAssertNotNil(layout.pill)
    }

    func testHexColorRoundTrip() {
        let color = RGBA(r: 16, g: 32, b: 64, a: 255)
        XCTAssertEqual(RGBA(hex: color.hex), color)
        XCTAssertEqual(PickerHSB(color: .red).color, .red)
    }
}

private enum PSDFixture {
    struct Layer {
        var name: String
        var top: Int32
        var left: Int32
        var bottom: Int32
        var right: Int32
        var opacity: UInt8 = 255
        var blend = "norm"
        var planes: [(Int16, [UInt8])] = []
        var section: UInt32?
    }

    static func file(width: UInt32, height: UInt32, resolutionPPI: UInt32?, layers: [Layer]) -> Data {
        var data = Data("8BPS".utf8)
        data.append(u16(1))
        data.append(Data(count: 6))
        data.append(u16(3))
        data.append(u32(height))
        data.append(u32(width))
        data.append(u16(8))
        data.append(u16(3))
        data.append(u32(0))
        if let resolutionPPI {
            var resources = Data("8BIM".utf8)
            resources.append(u16(1005))
            resources.append(0)
            resources.append(0)
            resources.append(u32(4))
            resources.append(u32(resolutionPPI * 65536))
            data.append(u32(UInt32(resources.count)))
            data.append(resources)
        } else {
            data.append(u32(0))
        }
        var records = Data()
        var channels = Data()
        for layer in layers {
            let built = record(layer)
            records.append(built.record)
            channels.append(built.channels)
        }
        var info = Data()
        info.append(i16(Int16(layers.count)))
        info.append(records)
        info.append(channels)
        var section = Data()
        section.append(u32(UInt32(info.count)))
        section.append(info)
        data.append(u32(UInt32(section.count)))
        data.append(section)
        return data
    }

    private static func record(_ layer: Layer) -> (record: Data, channels: Data) {
        var record = Data()
        record.append(i32(layer.top))
        record.append(i32(layer.left))
        record.append(i32(layer.bottom))
        record.append(i32(layer.right))
        record.append(u16(UInt16(layer.planes.count)))
        var channels = Data()
        for (id, samples) in layer.planes {
            var payload = Data([0, 0])
            payload.append(contentsOf: samples)
            record.append(i16(id))
            record.append(u32(UInt32(payload.count)))
            channels.append(payload)
        }
        record.append(contentsOf: Data("8BIM".utf8))
        var blend = Array(layer.blend.utf8.prefix(4))
        while blend.count < 4 { blend.append(0x20) }
        record.append(contentsOf: blend)
        record.append(layer.opacity)
        record.append(0)
        record.append(0)
        record.append(0)
        var extra = Data()
        extra.append(u32(0))
        extra.append(u32(0))
        let name = Array(layer.name.utf8)
        extra.append(UInt8(name.count))
        extra.append(contentsOf: name)
        let pad = (4 - ((name.count + 1) % 4)) % 4
        extra.append(Data(count: pad))
        if let section = layer.section {
            extra.append(contentsOf: Data("8BIM".utf8))
            extra.append(contentsOf: Data("lsct".utf8))
            extra.append(u32(4))
            extra.append(u32(section))
        }
        record.append(u32(UInt32(extra.count)))
        record.append(extra)
        return (record, channels)
    }

    private static func u16(_ value: UInt16) -> Data { Data([UInt8(value >> 8), UInt8(value & 0xff)]) }
    private static func u32(_ value: UInt32) -> Data {
        Data([UInt8(value >> 24), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
    }
    private static func i16(_ value: Int16) -> Data { u16(UInt16(bitPattern: value)) }
    private static func i32(_ value: Int32) -> Data { u32(UInt32(bitPattern: value)) }
}
