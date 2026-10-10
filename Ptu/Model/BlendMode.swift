// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics

enum BlendMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge
    case colorBurn
    case softLight
    case hardLight
    case difference
    case exclusion

    var id: String { rawValue }

    var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .darken: .darken
        case .lighten: .lighten
        case .colorDodge: .colorDodge
        case .colorBurn: .colorBurn
        case .softLight: .softLight
        case .hardLight: .hardLight
        case .difference: .difference
        case .exclusion: .exclusion
        }
    }

    var title: String {
        switch self {
        case .normal: L10n.Blend.normal
        case .multiply: L10n.Blend.multiply
        case .screen: L10n.Blend.screen
        case .overlay: L10n.Blend.overlay
        case .darken: L10n.Blend.darken
        case .lighten: L10n.Blend.lighten
        case .colorDodge: L10n.Blend.colorDodge
        case .colorBurn: L10n.Blend.colorBurn
        case .softLight: L10n.Blend.softLight
        case .hardLight: L10n.Blend.hardLight
        case .difference: L10n.Blend.difference
        case .exclusion: L10n.Blend.exclusion
        }
    }
}
