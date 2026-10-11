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
            nextGroupNumber: max(manifest.nextGroupNumber, 1),
            guides: (manifest.guides ?? []).compactMap(CanvasGuide.init)
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
            layers: model.layers.map(ManifestLayer.init),
            guides: model.guides.map(ManifestGuide.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    private static func pixelImages(in nodes: [LayerNode]) -> [(String, PixelBuffer)] {
        nodes.flatMap { node -> [(String, PixelBuffer)] in
            switch node {
            case .pixels(let layer):
                var images = [("\(layer.id.uuidString).png", layer.buffer)]
                if let mask = layer.mask {
                    images.append(("\(layer.id.uuidString)-mask.png", mask.buffer))
                }
                return images
            case .group(let group):
                var images = pixelImages(in: group.children)
                if let mask = group.mask {
                    images.append(("\(group.id.uuidString)-mask.png", mask.buffer))
                }
                return images
            case .adjustment(let layer):
                guard let mask = layer.mask else { return [] }
                return [("\(layer.id.uuidString)-mask.png", mask.buffer)]
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
                buffer: decoded.buffer,
                mask: try readMask(record, files: files),
                maskSourceID: record.maskSourceID,
                effects: record.effects ?? LayerEffects()
            ))
        case "group":
            let children = try (record.children ?? []).map { try readLayer($0, files: files) }
            return .group(GroupLayer(
                id: record.id,
                name: record.name,
                isVisible: record.visible,
                opacity: opacity,
                blend: blend,
                children: children,
                mask: try readMask(record, files: files)
            ))
        case "adjustment":
            guard let adjustment = record.adjustment else { throw DocumentError.unreadable }
            return .adjustment(AdjustmentLayer(
                id: record.id,
                name: record.name,
                isVisible: record.visible,
                opacity: opacity,
                blend: blend,
                adjustment: adjustment,
                mask: try readMask(record, files: files),
                maskSourceID: record.maskSourceID
            ))
        default:
            throw DocumentError.unreadable
        }
    }

    private static func readMask(_ record: ManifestLayer, files: [String: FileWrapper]) throws -> LayerMask? {
        guard let name = record.mask else { return nil }
        guard let data = files[name]?.regularFileContents else { throw DocumentError.unreadable }
        let decoded = try ImageFiles.decode(data)
        return LayerMask(buffer: decoded.buffer, isEnabled: record.maskEnabled ?? true)
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
    var guides: [ManifestGuide]?
}

private struct ManifestGuide: Codable {
    var id: UUID
    var axis: String
    var position: Double

    init(_ guide: CanvasGuide) {
        id = guide.id
        axis = guide.axis.rawValue
        position = guide.position
    }
}

extension CanvasGuide {
    fileprivate init?(_ record: ManifestGuide) {
        guard let axis = Axis(rawValue: record.axis) else { return nil }
        self.init(id: record.id, axis: axis, position: record.position)
    }
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
    var mask: String?
    var maskEnabled: Bool?
    var maskSourceID: UUID?
    var effects: LayerEffects?
    var adjustment: LayerAdjustment?

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
            mask = layer.mask == nil ? nil : "\(layer.id.uuidString)-mask.png"
            maskEnabled = layer.mask?.isEnabled
            maskSourceID = layer.maskSourceID
            effects = layer.effects.isEmpty ? nil : layer.effects
            adjustment = nil
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
            mask = group.mask == nil ? nil : "\(group.id.uuidString)-mask.png"
            maskEnabled = group.mask?.isEnabled
            maskSourceID = nil
            effects = nil
            adjustment = nil
        case .adjustment(let layer):
            kind = "adjustment"
            id = layer.id
            name = layer.name
            visible = layer.isVisible
            opacity = layer.opacity
            blend = layer.blend.rawValue
            originX = nil
            originY = nil
            image = nil
            children = nil
            mask = layer.mask == nil ? nil : "\(layer.id.uuidString)-mask.png"
            maskEnabled = layer.mask?.isEnabled
            maskSourceID = layer.maskSourceID
            effects = nil
            adjustment = layer.adjustment
        }
    }
}
