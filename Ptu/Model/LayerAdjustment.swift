// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

enum AdjustmentKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case levels
    case curves
    case hueSaturation
    case exposure
    case blackWhite
    case colorBalance
    case gradientMap
    case grain
    case invert
    case gaussianBlur
    case motionBlur
    case addNoise
    case vignette
    case bloomGlow
    case dither
    case tonalContrast
    case cameraRaw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .levels: L10n.Adjust.levels
        case .curves: L10n.Adjust.curves
        case .hueSaturation: L10n.Adjust.hueSaturation
        case .exposure: L10n.Adjust.exposure
        case .blackWhite: L10n.Adjust.blackWhite
        case .colorBalance: L10n.Adjust.colorBalance
        case .gradientMap: L10n.Adjust.gradientMap
        case .grain: L10n.Adjust.grain
        case .invert: L10n.Adjust.invert
        case .gaussianBlur: L10n.Filter.gaussianBlur
        case .motionBlur: L10n.Filter.motionBlur
        case .addNoise: L10n.Filter.addNoise
        case .vignette: L10n.Filter.vignette
        case .bloomGlow: L10n.Filter.bloom
        case .dither: L10n.Filter.dither
        case .tonalContrast: L10n.Filter.tonalContrast
        case .cameraRaw: L10n.Adjust.cameraRaw
        }
    }

    var samplesNeighbors: Bool {
        switch self {
        case .gaussianBlur, .motionBlur, .bloomGlow, .tonalContrast, .dither, .cameraRaw:
            return true
        default:
            return false
        }
    }
}

struct LayerAdjustment: Codable, Equatable, Sendable {
    var kind: AdjustmentKind

    init(kind: AdjustmentKind) {
        self.kind = kind
    }
    var hueSaturation = HueSaturationSettings()
    var levels = LevelsSettings()
    var curves = CurvesSettings()
    var exposure = ExposureSettings()
    var gradientMap = GradientMapSettings()
    var grain = GrainSettings()
    var blackWhite = BlackWhiteSettings()
    var colorBalance = ColorBalanceSettings()
    var filter = FilterSettings()
    var cameraRaw = CameraRawSettings()

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        switch kind {
        case .levels: return levels.apply(buffer)
        case .curves: return curves.apply(buffer)
        case .hueSaturation: return hueSaturation.apply(buffer)
        case .exposure: return exposure.apply(buffer)
        case .blackWhite: return blackWhite.apply(buffer)
        case .colorBalance: return colorBalance.apply(buffer)
        case .gradientMap: return gradientMap.apply(buffer)
        case .grain: return grain.apply(buffer)
        case .invert: return InvertAdjustment.apply(buffer)
        case .gaussianBlur: return PixelFilter.apply(.gaussianBlur, to: buffer, settings: filter)
        case .motionBlur: return PixelFilter.apply(.motionBlur, to: buffer, settings: filter)
        case .addNoise: return PixelFilter.apply(.addNoise, to: buffer, settings: filter)
        case .vignette: return PixelFilter.apply(.vignette, to: buffer, settings: filter)
        case .bloomGlow: return PixelFilter.apply(.bloomGlow, to: buffer, settings: filter)
        case .dither: return PixelFilter.apply(.dither, to: buffer, settings: filter)
        case .tonalContrast: return PixelFilter.apply(.tonalContrast, to: buffer, settings: filter)
        case .cameraRaw: return cameraRaw.apply(buffer)
        }
    }
}
