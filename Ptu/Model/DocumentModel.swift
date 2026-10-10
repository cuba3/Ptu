// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum CanvasBackground: String, CaseIterable, Identifiable, Sendable {
    case transparent
    case white

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transparent: L10n.Canvas.backgroundTransparent
        case .white: L10n.Canvas.backgroundWhite
        }
    }

    var fill: RGBA {
        switch self {
        case .transparent: .clear
        case .white: .white
        }
    }
}

struct DocumentModel: Equatable, Sendable {
    static let minimumSide = 1
    static let maximumSide = 16_000

    var width: Int
    var height: Int
    var resolutionPPI: Double
    /// Index 0 is the front-most layer.
    var layers: [LayerNode]
    var nextLayerNumber: Int
    var nextGroupNumber: Int

    static func blank(
        width: Int = 1920,
        height: Int = 1080,
        resolutionPPI: Double = 72,
        background: CanvasBackground = .transparent
    ) -> DocumentModel {
        let safeWidth = min(max(width, minimumSide), maximumSide)
        let safeHeight = min(max(height, minimumSide), maximumSide)
        let safePPI = min(max(resolutionPPI, 1), 2400)
        let layer = PixelLayer(
            id: UUID(),
            name: L10n.Layer.defaultName(1),
            isVisible: true,
            opacity: 1,
            blend: .normal,
            originX: 0,
            originY: 0,
            buffer: PixelBuffer(width: safeWidth, height: safeHeight, fill: background.fill)
        )
        return DocumentModel(
            width: safeWidth,
            height: safeHeight,
            resolutionPPI: safePPI,
            layers: [.pixels(layer)],
            nextLayerNumber: 2,
            nextGroupNumber: 1
        )
    }

    static func imported(buffer: PixelBuffer, resolutionPPI: Double, name: String) -> DocumentModel {
        let layer = PixelLayer(
            id: UUID(),
            name: name,
            isVisible: true,
            opacity: 1,
            blend: .normal,
            originX: 0,
            originY: 0,
            buffer: buffer
        )
        return DocumentModel(
            width: buffer.width,
            height: buffer.height,
            resolutionPPI: min(max(resolutionPPI, 1), 2400),
            layers: [.pixels(layer)],
            nextLayerNumber: 2,
            nextGroupNumber: 1
        )
    }

    func node(id: UUID) -> LayerNode? {
        find(id, in: layers)
    }

    func pixelLayer(id: UUID) -> PixelLayer? {
        if case .pixels(let layer) = node(id: id) { return layer }
        return nil
    }

    @discardableResult
    mutating func update(id: UUID, _ body: (inout LayerNode) -> Void) -> Bool {
        update(id: id, in: &layers, body)
    }

    mutating func addPixelLayer() -> UUID {
        let number = nextLayerNumber
        nextLayerNumber += 1
        let layer = PixelLayer(
            id: UUID(),
            name: L10n.Layer.defaultName(number),
            isVisible: true,
            opacity: 1,
            blend: .normal,
            originX: 0,
            originY: 0,
            buffer: PixelBuffer(width: width, height: height, fill: .clear)
        )
        layers.insert(.pixels(layer), at: 0)
        return layer.id
    }

    mutating func addGroup() -> UUID {
        let number = nextGroupNumber
        nextGroupNumber += 1
        let group = GroupLayer(
            id: UUID(),
            name: L10n.Layer.defaultGroupName(number),
            isVisible: true,
            opacity: 1,
            blend: .normal,
            children: []
        )
        layers.insert(.group(group), at: 0)
        return group.id
    }

    mutating func delete(id: UUID) {
        layers = removing(id, from: layers)
    }

    mutating func duplicate(id: UUID) -> UUID? {
        var created: UUID?
        func walk(_ nodes: inout [LayerNode]) -> Bool {
            for index in nodes.indices {
                if nodes[index].id == id {
                    let copy = Self.duplicated(nodes[index])
                    created = copy.id
                    nodes.insert(copy, at: index)
                    return true
                }
                if case .group(var group) = nodes[index], walk(&group.children) {
                    nodes[index] = .group(group)
                    return true
                }
            }
            return false
        }
        _ = walk(&layers)
        return created
    }

    mutating func move(parentID: UUID?, from offsets: IndexSet, to destination: Int) {
        if let parentID {
            guard update(id: parentID, { node in
                guard case .group(var group) = node else { return }
                group.children.move(fromOffsets: offsets, toOffset: destination)
                node = .group(group)
            }) else { return }
        } else {
            layers.move(fromOffsets: offsets, toOffset: destination)
        }
    }

    mutating func move(id: UUID, towardFront: Bool) {
        func walk(_ nodes: inout [LayerNode]) -> Bool {
            for index in nodes.indices {
                if nodes[index].id == id {
                    let target = towardFront ? index - 1 : index + 1
                    guard nodes.indices.contains(target) else { return true }
                    nodes.swapAt(index, target)
                    return true
                }
                if case .group(var group) = nodes[index], walk(&group.children) {
                    nodes[index] = .group(group)
                    return true
                }
            }
            return false
        }
        _ = walk(&layers)
    }

    mutating func setName(id: UUID, name: String) {
        update(id: id) { node in
            switch node {
            case .pixels(var layer):
                layer.name = name
                node = .pixels(layer)
            case .group(var layer):
                layer.name = name
                node = .group(layer)
            }
        }
    }

    mutating func setVisible(id: UUID, isVisible: Bool) {
        update(id: id) { node in
            switch node {
            case .pixels(var layer):
                layer.isVisible = isVisible
                node = .pixels(layer)
            case .group(var layer):
                layer.isVisible = isVisible
                node = .group(layer)
            }
        }
    }

    mutating func setOpacity(id: UUID, opacity: Double) {
        let clamped = min(max(opacity, 0), 1)
        update(id: id) { node in
            switch node {
            case .pixels(var layer):
                layer.opacity = clamped
                node = .pixels(layer)
            case .group(var layer):
                layer.opacity = clamped
                node = .group(layer)
            }
        }
    }

    mutating func setBlend(id: UUID, blend: BlendMode) {
        update(id: id) { node in
            switch node {
            case .pixels(var layer):
                layer.blend = blend
                node = .pixels(layer)
            case .group(var layer):
                layer.blend = blend
                node = .group(layer)
            }
        }
    }

    mutating func offset(id: UUID, dx: Int, dy: Int) {
        guard dx != 0 || dy != 0 else { return }
        update(id: id) { node in
            node = node.offset(dx: dx, dy: dy)
        }
    }

    @discardableResult
    mutating func stamp(
        layerID: UUID,
        documentCenter: CGPoint,
        radius: CGFloat,
        hardness: CGFloat,
        opacity: CGFloat,
        color: RGBA
    ) -> CGRect? {
        guard var layer = pixelLayer(id: layerID) else { return nil }
        let local = CGPoint(
            x: documentCenter.x - CGFloat(layer.originX),
            y: documentCenter.y - CGFloat(layer.originY)
        )
        let dirtyLocal = layer.buffer.stamp(
            center: local,
            radius: radius,
            hardness: hardness,
            opacity: opacity,
            color: color
        )
        guard !dirtyLocal.isNull else { return nil }
        update(id: layerID) { node in
            node = .pixels(layer)
        }
        return dirtyLocal.offsetBy(dx: CGFloat(layer.originX), dy: CGFloat(layer.originY))
    }

    mutating func clear(selection: CGRect, layerID: UUID) {
        let area = selection.standardized
        guard area.width >= 1, area.height >= 1 else { return }
        update(id: layerID) { node in
            node = node.clearing(selection: area)
        }
    }

    mutating func crop(to rect: CGRect) {
        guard let area = CropPixels.rect(rect, canvasWidth: width, canvasHeight: height) else { return }
        let cropX = Int(area.minX)
        let cropY = Int(area.minY)
        let cropWidth = Int(area.width)
        let cropHeight = Int(area.height)
        layers = layers.map { $0.cropped(toX: cropX, y: cropY, width: cropWidth, height: cropHeight) }
        width = cropWidth
        height = cropHeight
    }

    private func find(_ id: UUID, in nodes: [LayerNode]) -> LayerNode? {
        for node in nodes {
            if node.id == id { return node }
            if case .group(let group) = node, let found = find(id, in: group.children) {
                return found
            }
        }
        return nil
    }

    private func update(
        id: UUID,
        in nodes: inout [LayerNode],
        _ body: (inout LayerNode) -> Void
    ) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == id {
                body(&nodes[index])
                return true
            }
            if case .group(var group) = nodes[index], update(id: id, in: &group.children, body) {
                nodes[index] = .group(group)
                return true
            }
        }
        return false
    }

    private func removing(_ id: UUID, from nodes: [LayerNode]) -> [LayerNode] {
        nodes.compactMap { node in
            if node.id == id { return nil }
            if case .group(var group) = node {
                group.children = removing(id, from: group.children)
                return .group(group)
            }
            return node
        }
    }

    private static func duplicated(_ node: LayerNode) -> LayerNode {
        switch node {
        case .pixels(var layer):
            layer.id = UUID()
            layer.name = L10n.Layer.copyName(layer.name)
            return .pixels(layer)
        case .group(var group):
            group.id = UUID()
            group.name = L10n.Layer.copyName(group.name)
            group.children = group.children.map { duplicated($0) }
            return .group(group)
        }
    }
}

private extension LayerNode {
    func offset(dx: Int, dy: Int) -> LayerNode {
        switch self {
        case .pixels(var layer):
            layer.originX += dx
            layer.originY += dy
            return .pixels(layer)
        case .group(var group):
            group.children = group.children.map { $0.offset(dx: dx, dy: dy) }
            return .group(group)
        }
    }

    func clearing(selection: CGRect) -> LayerNode {
        switch self {
        case .pixels(var layer):
            let local = selection.offsetBy(dx: -CGFloat(layer.originX), dy: -CGFloat(layer.originY))
            layer.buffer.clear(rect: local)
            return .pixels(layer)
        case .group(var group):
            group.children = group.children.map { $0.clearing(selection: selection) }
            return .group(group)
        }
    }

    func cropped(toX cropX: Int, y cropY: Int, width cropWidth: Int, height cropHeight: Int) -> LayerNode {
        switch self {
        case .pixels(var layer):
            let x0 = max(layer.originX, cropX)
            let y0 = max(layer.originY, cropY)
            let x1 = min(layer.originX + layer.buffer.width, cropX + cropWidth)
            let y1 = min(layer.originY + layer.buffer.height, cropY + cropHeight)
            guard x1 - x0 >= 1, y1 - y0 >= 1 else {
                layer.buffer = PixelBuffer(width: 1, height: 1, fill: .clear)
                layer.originX = 0
                layer.originY = 0
                return .pixels(layer)
            }
            layer.buffer = layer.buffer.cropped(
                minX: x0 - layer.originX,
                minY: y0 - layer.originY,
                width: x1 - x0,
                height: y1 - y0
            )
            layer.originX = x0 - cropX
            layer.originY = y0 - cropY
            return .pixels(layer)
        case .group(var group):
            group.children = group.children.map {
                $0.cropped(toX: cropX, y: cropY, width: cropWidth, height: cropHeight)
            }
            return .group(group)
        }
    }
}

/// Integer pixel bounds of a crop. The left and top edges round down, the right and bottom round up.
enum CropPixels {
    static func rect(_ rect: CGRect, canvasWidth: Int, canvasHeight: Int) -> CGRect? {
        let rect = rect.standardized
        guard rect.width > 0, rect.height > 0, canvasWidth >= 1, canvasHeight >= 1 else { return nil }
        let minX = max(0, Int(floor(rect.minX)))
        let minY = max(0, Int(floor(rect.minY)))
        let maxX = min(canvasWidth, max(minX + 1, Int(ceil(rect.maxX))))
        let maxY = min(canvasHeight, max(minY + 1, Int(ceil(rect.maxY))))
        let width = maxX - minX
        let height = maxY - minY
        guard width >= 1, height >= 1 else { return nil }
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
}

private extension Array {
    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.sorted().map { self[$0] }
        for index in offsets.sorted(by: >) {
            remove(at: index)
        }
        let adjusted = destination - offsets.filter { $0 < destination }.count
        let insertion = Swift.min(Swift.max(adjusted, 0), count)
        insert(contentsOf: moving, at: insertion)
    }
}
