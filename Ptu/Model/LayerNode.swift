// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

struct PixelLayer: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var isVisible: Bool
    var opacity: Double
    var blend: BlendMode
    var originX: Int
    var originY: Int
    var buffer: PixelBuffer
    var mask: LayerMask?
    var maskSourceID: UUID?
    var effects: LayerEffects

    var bounds: CGRect {
        CGRect(x: originX, y: originY, width: buffer.width, height: buffer.height)
    }

    init(
        id: UUID,
        name: String,
        isVisible: Bool,
        opacity: Double,
        blend: BlendMode,
        originX: Int,
        originY: Int,
        buffer: PixelBuffer,
        mask: LayerMask? = nil,
        maskSourceID: UUID? = nil,
        effects: LayerEffects = LayerEffects()
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.opacity = opacity
        self.blend = blend
        self.originX = originX
        self.originY = originY
        self.buffer = buffer
        self.mask = mask
        self.maskSourceID = maskSourceID
        self.effects = effects
    }
}

struct GroupLayer: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var isVisible: Bool
    var opacity: Double
    var blend: BlendMode
    var children: [LayerNode]
    var mask: LayerMask?

    init(
        id: UUID,
        name: String,
        isVisible: Bool,
        opacity: Double,
        blend: BlendMode,
        children: [LayerNode],
        mask: LayerMask? = nil
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.opacity = opacity
        self.blend = blend
        self.children = children
        self.mask = mask
    }
}

struct AdjustmentLayer: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var isVisible: Bool
    var opacity: Double
    var blend: BlendMode
    var adjustment: LayerAdjustment
    var mask: LayerMask?
    var maskSourceID: UUID?
}

enum LayerNode: Equatable, Identifiable, Sendable {
    case pixels(PixelLayer)
    case group(GroupLayer)
    case adjustment(AdjustmentLayer)

    var id: UUID {
        switch self {
        case .pixels(let layer): layer.id
        case .group(let layer): layer.id
        case .adjustment(let layer): layer.id
        }
    }

    var name: String {
        switch self {
        case .pixels(let layer): layer.name
        case .group(let layer): layer.name
        case .adjustment(let layer): layer.name
        }
    }

    var isVisible: Bool {
        switch self {
        case .pixels(let layer): layer.isVisible
        case .group(let layer): layer.isVisible
        case .adjustment(let layer): layer.isVisible
        }
    }

    var opacity: Double {
        switch self {
        case .pixels(let layer): layer.opacity
        case .group(let layer): layer.opacity
        case .adjustment(let layer): layer.opacity
        }
    }

    var blend: BlendMode {
        switch self {
        case .pixels(let layer): layer.blend
        case .group(let layer): layer.blend
        case .adjustment(let layer): layer.blend
        }
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }

    var isAdjustment: Bool {
        if case .adjustment = self { return true }
        return false
    }

    var containsAdjustment: Bool {
        switch self {
        case .adjustment:
            return true
        case .pixels:
            return false
        case .group(let group):
            return group.children.contains { $0.containsAdjustment }
        }
    }

    var mask: LayerMask? {
        switch self {
        case .pixels(let layer): layer.mask
        case .group(let layer): layer.mask
        case .adjustment(let layer): layer.mask
        }
    }
}
