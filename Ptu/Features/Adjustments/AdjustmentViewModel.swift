// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation
import Observation

enum AdjustmentSheetKind: String, Identifiable, Sendable {
    case levels
    case curves
    case hueSaturation
    case exposure
    case blackWhite
    case colorBalance
    case gradientMap
    case grain
    case gaussianBlur
    case motionBlur
    case addNoise
    case vignette
    case bloomGlow
    case tonalContrast
    case dither
    case lensCorrection
    case cameraRaw
    case rawDevelop

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
        case .gaussianBlur: L10n.Filter.gaussianBlur
        case .motionBlur: L10n.Filter.motionBlur
        case .addNoise: L10n.Filter.addNoise
        case .vignette: L10n.Filter.vignette
        case .bloomGlow: L10n.Filter.bloom
        case .tonalContrast: L10n.Filter.tonalContrast
        case .dither: L10n.Filter.dither
        case .lensCorrection: L10n.Filter.lensCorrection
        case .cameraRaw: L10n.Adjust.cameraRaw
        case .rawDevelop: L10n.MenuImage.developRaw
        }
    }

    var adjustmentKind: AdjustmentKind? {
        switch self {
        case .levels: .levels
        case .curves: .curves
        case .hueSaturation: .hueSaturation
        case .exposure: .exposure
        case .blackWhite: .blackWhite
        case .colorBalance: .colorBalance
        case .gradientMap: .gradientMap
        case .grain: .grain
        case .gaussianBlur: .gaussianBlur
        case .motionBlur: .motionBlur
        case .addNoise: .addNoise
        case .vignette: .vignette
        case .bloomGlow: .bloomGlow
        case .tonalContrast: .tonalContrast
        case .dither: .dither
        case .lensCorrection: nil
        case .cameraRaw: .cameraRaw
        case .rawDevelop: nil
        }
    }
}

enum ImageCommand: Sendable {
    case bake(AdjustmentSheetKind)
    case invert
    case developRaw
    case addMask
    case deleteMask
    case invertMask
    case toggleMask
    case editMask
    case clippingMask
    case releaseClipping
    case newAdjustment(AdjustmentKind)
    case toggleEffect(LayerEffectKind)
}

@MainActor
@Observable
final class AdjustmentViewModel: Identifiable {
    let id = UUID()
    let kind: AdjustmentSheetKind
    private let document: EditorDocumentSession
    private let bakeLayerID: UUID?
    private let adjustmentLayerID: UUID?
    private let rawURL: URL?

    var levels = LevelsSettings()
    var curves = CurvesSettings()
    var hue = HueSaturationSettings()
    var exposure = ExposureSettings()
    var blackWhite = BlackWhiteSettings()
    var colorBalance = ColorBalanceSettings()
    var gradientMap = GradientMapSettings()
    var grain = GrainSettings()
    var filter = FilterSettings()
    var cameraRaw = CameraRawSettings()
    var raw = RawDevelopSettings()

    init(
        kind: AdjustmentSheetKind,
        document: EditorDocumentSession,
        bakeLayerID: UUID?,
        adjustmentLayerID: UUID?,
        rawURL: URL?,
        rawSettings: RawDevelopSettings?
    ) {
        self.kind = kind
        self.document = document
        self.bakeLayerID = bakeLayerID
        self.adjustmentLayerID = adjustmentLayerID
        self.rawURL = rawURL
        if let rawSettings { raw = rawSettings }
        if let adjustmentLayerID, case .adjustment(let layer) = document.model.node(id: adjustmentLayerID) {
            load(layer.adjustment)
        }
        if grain.seed == 0 { grain.seed = .random(in: .min ... .max) }
        if filter.seed == 0 { filter.seed = .random(in: .min ... .max) }
        if cameraRaw.grainSeed == 0 { cameraRaw.grainSeed = .random(in: .min ... .max) }
    }

    func apply() {
        if kind == .rawDevelop {
            developRaw()
            return
        }
        if let adjustmentLayerID {
            document.edit(redraw: .full) { model in
                model.setAdjustment(id: adjustmentLayerID, adjustment: self.makeAdjustment())
            }
            return
        }
        guard let bakeLayerID, let source = document.model.pixelLayer(id: bakeLayerID) else { return }
        let rendered = render(source.buffer)
        document.edit(redraw: .full) { model in
            model.replacePixels(id: bakeLayerID, buffer: rendered)
        }
    }

    func resetRaw() {
        raw.reset()
    }

    private func developRaw() {
        guard let rawURL, let buffer = RawImporter.develop(rawURL, settings: raw) else { return }
        let name = rawURL.deletingPathExtension().lastPathComponent
        document.replaceDocument(DocumentModel.imported(buffer: buffer, resolutionPPI: 72, name: name))
    }

    private func load(_ adjustment: LayerAdjustment) {
        levels = adjustment.levels
        curves = adjustment.curves
        hue = adjustment.hueSaturation
        exposure = adjustment.exposure
        blackWhite = adjustment.blackWhite
        colorBalance = adjustment.colorBalance
        gradientMap = adjustment.gradientMap
        grain = adjustment.grain
        filter = adjustment.filter
        cameraRaw = adjustment.cameraRaw
    }

    private func makeAdjustment() -> LayerAdjustment {
        var adjustment = LayerAdjustment(kind: kind.adjustmentKind ?? .levels)
        adjustment.levels = levels
        adjustment.curves = curves
        adjustment.hueSaturation = hue
        adjustment.exposure = exposure
        adjustment.blackWhite = blackWhite
        adjustment.colorBalance = colorBalance
        adjustment.gradientMap = gradientMap
        adjustment.grain = grain
        adjustment.filter = filter
        adjustment.cameraRaw = cameraRaw
        return adjustment
    }

    private func render(_ buffer: PixelBuffer) -> PixelBuffer {
        switch kind {
        case .levels: levels.apply(buffer)
        case .curves: curves.apply(buffer)
        case .hueSaturation: hue.apply(buffer)
        case .exposure: exposure.apply(buffer)
        case .blackWhite: blackWhite.apply(buffer)
        case .colorBalance: colorBalance.apply(buffer)
        case .gradientMap: gradientMap.apply(buffer)
        case .grain: grain.apply(buffer)
        case .gaussianBlur: PixelFilter.apply(.gaussianBlur, to: buffer, settings: filter)
        case .motionBlur: PixelFilter.apply(.motionBlur, to: buffer, settings: filter)
        case .addNoise: PixelFilter.apply(.addNoise, to: buffer, settings: filter)
        case .vignette: PixelFilter.apply(.vignette, to: buffer, settings: filter)
        case .bloomGlow: PixelFilter.apply(.bloomGlow, to: buffer, settings: filter)
        case .tonalContrast: PixelFilter.apply(.tonalContrast, to: buffer, settings: filter)
        case .dither: PixelFilter.apply(.dither, to: buffer, settings: filter)
        case .lensCorrection: PixelFilter.apply(.lensCorrection, to: buffer, settings: filter)
        case .cameraRaw: cameraRaw.apply(buffer)
        case .rawDevelop: buffer
        }
    }
}
