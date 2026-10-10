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

    var bounds: CGRect {
        CGRect(x: originX, y: originY, width: buffer.width, height: buffer.height)
    }
}

struct GroupLayer: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var isVisible: Bool
    var opacity: Double
    var blend: BlendMode
    var children: [LayerNode]
}

enum LayerNode: Equatable, Identifiable, Sendable {
    case pixels(PixelLayer)
    case group(GroupLayer)

    var id: UUID {
        switch self {
        case .pixels(let layer): layer.id
        case .group(let layer): layer.id
        }
    }

    var name: String {
        switch self {
        case .pixels(let layer): layer.name
        case .group(let layer): layer.name
        }
    }

    var isVisible: Bool {
        switch self {
        case .pixels(let layer): layer.isVisible
        case .group(let layer): layer.isVisible
        }
    }

    var opacity: Double {
        switch self {
        case .pixels(let layer): layer.opacity
        case .group(let layer): layer.opacity
        }
    }

    var blend: BlendMode {
        switch self {
        case .pixels(let layer): layer.blend
        case .group(let layer): layer.blend
        }
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }
}
