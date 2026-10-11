// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum PSDImporter {
    static func read(_ data: Data) throws -> PSDImportResult {
        try PSDDocumentBuilder.make(PSDReader.read(data))
    }

    static func read(url: URL) throws -> PSDImportResult {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try read(data)
    }
}

enum PSDDocumentBuilder {
    static func make(_ document: PSDDocument) -> PSDImportResult {
        var notes: [PSDConversionNote] = []
        var built: [(record: PSDRecord, node: LayerNode?)] = []
        for record in document.layers {
            notes.append(contentsOf: conversionNotes(for: record))
            if record.kind == .adjustment {
                built.append((record, nil))
                continue
            }
            built.append((record, makeNode(record)))
        }
        let layers = children(of: nil, in: built)
        var pixelCount = 0
        var groupCount = 0
        func tally(_ nodes: [LayerNode]) {
            for node in nodes {
                switch node {
                case .pixels:
                    pixelCount += 1
                case .adjustment:
                    pixelCount += 1
                case .group(let group):
                    groupCount += 1
                    tally(group.children)
                }
            }
        }
        tally(layers)
        let model = DocumentModel(
            width: min(max(document.width, DocumentModel.minimumSide), DocumentModel.maximumSide),
            height: min(max(document.height, DocumentModel.minimumSide), DocumentModel.maximumSide),
            resolutionPPI: min(max(document.resolution, 1), 2400),
            layers: layers,
            nextLayerNumber: max(pixelCount + 1, 1),
            nextGroupNumber: max(groupCount + 1, 1)
        )
        return PSDImportResult(model: model, notes: notes)
    }

    private static func children(of parent: UUID?, in built: [(record: PSDRecord, node: LayerNode?)]) -> [LayerNode] {
        let kids = built.filter { $0.record.parentID == parent && $0.node != nil }
        return kids.reversed().compactMap { item in
            guard var node = item.node else { return nil }
            if item.record.isGroup, case .group(var group) = node {
                group.children = children(of: item.record.id, in: built)
                node = .group(group)
            }
            return node
        }
    }

    private static func makeNode(_ record: PSDRecord) -> LayerNode {
        let opacity = min(max(record.opacity, 0), 1)
        let blend = resolvedBlend(record)
        let name = record.name.isEmpty ? L10n.Layer.defaultName(1) : record.name
        if record.isGroup {
            return .group(GroupLayer(
                id: record.id,
                name: name,
                isVisible: record.isVisible,
                opacity: opacity,
                blend: blend,
                children: []
            ))
        }
        let originX = Int(record.bounds.minX.rounded())
        let originY = Int(record.bounds.minY.rounded())
        let buffer = record.image.flatMap { PixelBuffer.from(cgImage: $0) }
            ?? PixelBuffer(width: 1, height: 1, fill: .clear)
        return .pixels(PixelLayer(
            id: record.id,
            name: name,
            isVisible: record.isVisible,
            opacity: opacity,
            blend: blend,
            originX: originX,
            originY: originY,
            buffer: buffer
        ))
    }

    private static func resolvedBlend(_ record: PSDRecord) -> BlendMode {
        if record.isGroup, record.blendKey == "pass" { return .normal }
        return BlendMode.fromPSD(record.blendKey) ?? .normal
    }

    private static func conversionNotes(for record: PSDRecord) -> [PSDConversionNote] {
        var messages: [String] = []
        if record.croppedToCanvas { messages.append(L10n.PSD.cropped) }
        switch record.kind {
        case .text: messages.append(L10n.PSD.text)
        case .smartObject: messages.append(L10n.PSD.smartObject)
        case .vector: messages.append(L10n.PSD.vector)
        case .effects: messages.append(L10n.PSD.effects)
        case .adjustment: messages.append(L10n.PSD.adjustment)
        case .other: messages.append(L10n.PSD.other)
        case .raster, .group: break
        }
        if record.hasEffects, record.kind != .effects { messages.append(L10n.PSD.effects) }
        if record.isGroup, record.blendKey == "pass" {
            messages.append(L10n.PSD.groupPass)
        } else if BlendMode.fromPSD(record.blendKey) == nil, record.blendKey != "pass" {
            messages.append(L10n.PSD.unsupportedBlend(displayKey(record.blendKey)))
        }
        if record.hasMask { messages.append(L10n.PSD.mask) }
        if record.clipping { messages.append(L10n.PSD.clipping) }
        if !record.isGroup, record.kind != .adjustment, record.image == nil {
            messages.append(L10n.PSD.noPixels)
        }
        return messages.map { PSDConversionNote(layerName: record.name, message: $0) }
    }

    private static func displayKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespaces)
    }
}
