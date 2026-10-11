// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum EditorTool: String, CaseIterable, Identifiable, Sendable {
    case move
    case marquee
    case lasso
    case wand
    case objectSelection
    case colorRange
    case brush
    case clone
    case heal
    case blur
    case smudge
    case crop
    case eyedropper
    case hand
    case zoom
    case type
    case shape
    case gradient

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        case .marquee: "rectangle.dashed"
        case .lasso: "lasso"
        case .wand: "wand.and.rays"
        case .objectSelection: "person.crop.rectangle"
        case .colorRange: "paintpalette"
        case .brush: "paintbrush"
        case .clone: "stamp"
        case .heal: "bandage"
        case .blur: "drop"
        case .smudge: "scribble"
        case .crop: "crop"
        case .eyedropper: "eyedropper"
        case .hand: "hand.draw"
        case .zoom: "magnifyingglass"
        case .type: "textformat"
        case .shape: "square.on.circle"
        case .gradient: "circle.lefthalf.filled"
        }
    }

    var title: String {
        switch self {
        case .move: L10n.Tool.move
        case .marquee: L10n.Tool.marquee
        case .lasso: L10n.Tool.lasso
        case .wand: L10n.Tool.wand
        case .objectSelection: L10n.Tool.objectSelection
        case .colorRange: L10n.Tool.colorRange
        case .brush: L10n.Tool.brush
        case .clone: L10n.Tool.clone
        case .heal: L10n.Tool.heal
        case .blur: L10n.Tool.blur
        case .smudge: L10n.Tool.smudge
        case .crop: L10n.Tool.crop
        case .eyedropper: L10n.Tool.eyedropper
        case .hand: L10n.Tool.hand
        case .zoom: L10n.Tool.zoom
        case .type: L10n.Tool.type
        case .shape: L10n.Tool.shape
        case .gradient: L10n.Tool.gradient
        }
    }

    var usesRoundCursor: Bool {
        switch self {
        case .brush, .clone, .heal, .blur, .smudge: true
        default: false
        }
    }

    var paintsContinuously: Bool {
        switch self {
        case .brush, .clone, .blur, .smudge: true
        default: false
        }
    }
}
