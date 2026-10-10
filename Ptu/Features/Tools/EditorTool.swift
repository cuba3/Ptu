// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum EditorTool: String, CaseIterable, Identifiable, Sendable {
    case move
    case marquee
    case brush
    case crop
    case eyedropper

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        case .marquee: "rectangle.dashed"
        case .brush: "paintbrush"
        case .crop: "crop"
        case .eyedropper: "eyedropper"
        }
    }

    var title: String {
        switch self {
        case .move: L10n.Tool.move
        case .marquee: L10n.Tool.marquee
        case .brush: L10n.Tool.brush
        case .crop: L10n.Tool.crop
        case .eyedropper: L10n.Tool.eyedropper
        }
    }
}
