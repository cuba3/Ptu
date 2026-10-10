// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

enum ProjectStore {
    static let formatVersion = 1
    static let manifestName = "manifest.json"
    static let layersDirectory = "layers"

    static func write(_ model: DocumentModel) throws -> FileWrapper {
        let manifest = try manifestData(for: model)
        let root = FileWrapper(directoryWithFileWrappers: [:])
        let manifestFile = FileWrapper(regularFileWithContents: manifest)
        manifestFile.preferredFilename = manifestName
        root.addFileWrapper(manifestFile)

        let layers = FileWrapper(directoryWithFileWrappers: [:])
        layers.preferredFilename = layersDirectory
        for (filename, image) in pixelImages(in: model.layers) {
            guard let cgImage = image.cgImage() else { throw DocumentError.unreadable }
            let png = try ImageFiles.pngData(from: cgImage, ppi: model.resolutionPPI)
            let file = FileWrapper(regularFileWithContents: png)
            file.preferredFilename = filename
            layers.addFileWrapper(file)
        }
        root.addFileWrapper(layers)
        return root
    }

    static func read(wrapper: FileWrapper) throws -> DocumentModel {
        guard let children = wrapper.fileWrappers,
              let manifestFile = children[manifestName],
              let manifestData = manifestFile.regularFileContents,
              let layerFiles = children[layersDirectory]?.fileWrappers else {
            throw DocumentError.unreadable
        }
        let decoder = JSONDecoder()
        let manifest: Manifest
        do {
            manifest = try decoder.decode(Manifest.self, from: manifestData)
        } catch {
            throw DocumentError.unreadable
        }
        guard manifest.formatVersion == formatVersion else { throw DocumentError.unsupportedVersion }
        guard manifest.width >= DocumentModel.minimumSide,
              manifest.height >= DocumentModel.minimumSide,
              manifest.width <= DocumentModel.maximumSide,
              manifest.height <= DocumentModel.maximumSide else {
            throw DocumentError.unreadable
        }
        let layers = try manifest.layers.map { try readLayer($0, files: layerFiles) }
        return DocumentModel(
            width: manifest.width,
            height: manifest.height,
            resolutionPPI: min(max(manifest.resolutionPPI, 1), 2400),
            layers: layers,
            nextLayerNumber: max(manifest.nextLayerNumber, 1),
            nextGroupNumber: max(manifest.nextGroupNumber, 1)
        )
    }

    private static func manifestData(for model: DocumentModel) throws -> Data {
        let manifest = Manifest(
            formatVersion: formatVersion,
            width: model.width,
            height: model.height,
            resolutionPPI: model.resolutionPPI,
            nextLayerNumber: model.nextLayerNumber,
            nextGroupNumber: model.nextGroupNumber,
            layers: model.layers.map(ManifestLayer.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    private static func pixelImages(in nodes: [LayerNode]) -> [(String, PixelBuffer)] {
        nodes.flatMap { node -> [(String, PixelBuffer)] in
            switch node {
            case .pixels(let layer):
                [("\(layer.id.uuidString).png", layer.buffer)]
            case .group(let group):
                pixelImages(in: group.children)
            }
        }
    }

    private static func readLayer(_ record: ManifestLayer, files: [String: FileWrapper]) throws -> LayerNode {
        guard let blend = BlendMode(rawValue: record.blend) else { throw DocumentError.unreadable }
        let opacity = min(max(record.opacity, 0), 1)
        switch record.kind {
        case "pixels":
            guard let imageName = record.image,
                  let file = files[imageName],
                  let data = file.regularFileContents else {
                throw DocumentError.unreadable
            }
            let decoded = try ImageFiles.decode(data)
            return .pixels(PixelLayer(
                id: record.id,
                name: record.name,
                isVisible: record.visible,
                opacity: opacity,
                blend: blend,
                originX: record.originX ?? 0,
                originY: record.originY ?? 0,
                buffer: decoded.buffer
            ))
        case "group":
            let children = try (record.children ?? []).map { try readLayer($0, files: files) }
            return .group(GroupLayer(
                id: record.id,
                name: record.name,
                isVisible: record.visible,
                opacity: opacity,
                blend: blend,
                children: children
            ))
        default:
            throw DocumentError.unreadable
        }
    }
}

private struct Manifest: Codable {
    var formatVersion: Int
    var width: Int
    var height: Int
    var resolutionPPI: Double
    var nextLayerNumber: Int
    var nextGroupNumber: Int
    var layers: [ManifestLayer]
}

private struct ManifestLayer: Codable {
    var kind: String
    var id: UUID
    var name: String
    var visible: Bool
    var opacity: Double
    var blend: String
    var originX: Int?
    var originY: Int?
    var image: String?
    var children: [ManifestLayer]?

    init(_ node: LayerNode) {
        switch node {
        case .pixels(let layer):
            kind = "pixels"
            id = layer.id
            name = layer.name
            visible = layer.isVisible
            opacity = layer.opacity
            blend = layer.blend.rawValue
            originX = layer.originX
            originY = layer.originY
            image = "\(layer.id.uuidString).png"
            children = nil
        case .group(let group):
            kind = "group"
            id = group.id
            name = group.name
            visible = group.isVisible
            opacity = group.opacity
            blend = group.blend.rawValue
            originX = nil
            originY = nil
            image = nil
            children = group.children.map(ManifestLayer.init)
        }
    }
}
