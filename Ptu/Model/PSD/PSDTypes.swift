// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum PSDLimits {
    static let maxSide = DocumentModel.maximumSide
    static let maxSurfacePixels = DocumentModel.maximumSide * DocumentModel.maximumSide
    /// Several full-canvas layers, cropped to the canvas when a file would exceed this.
    static let documentPixelBudget = DocumentModel.maximumSide * DocumentModel.maximumSide * 8
}

enum PSDError: LocalizedError, Equatable {
    case truncated
    case unsupportedVersion
    case unsupportedColorMode
    case unsupportedDepth
    case unsupportedCompression
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .truncated: L10n.PSD.truncated
        case .unsupportedVersion: L10n.PSD.unsupportedVersion
        case .unsupportedColorMode: L10n.PSD.unsupportedColorMode
        case .unsupportedDepth: L10n.PSD.unsupportedDepth
        case .unsupportedCompression: L10n.PSD.unsupportedCompression
        case .tooLarge: L10n.PSD.tooLarge
        }
    }
}

struct PSDConversionNote: Identifiable, Equatable, Sendable {
    let id: UUID
    let layerName: String
    let message: String

    init(id: UUID = UUID(), layerName: String, message: String) {
        self.id = id
        self.layerName = layerName
        self.message = message
    }
}

struct PSDImportResult: Sendable {
    var model: DocumentModel
    var notes: [PSDConversionNote]
}

struct PSDDocument: @unchecked Sendable {
    var width: Int
    var height: Int
    var resolution: Double
    /// Bottom to top. Hidden section dividers are not stored.
    var layers: [PSDRecord]
}

struct PSDRecord: @unchecked Sendable {
    var id: UUID
    var parentID: UUID?
    var name: String
    var isGroup = false
    var isVisible = true
    var opacity: Double = 1
    var blendKey = "norm"
    var clipping = false
    var croppedToCanvas = false
    var bounds = CGRect.zero
    var image: CGImage?
    var hasMask = false
    var hasEffects = false
    var kind = PSDLayerKind.raster
}

enum PSDLayerKind: Equatable, Sendable {
    case raster
    case group
    case adjustment
    case text
    case smartObject
    case effects
    case vector
    case other
}

extension BlendMode {
    /// Photoshop blend keys are four characters. Modes Ptu cannot composite return nil.
    static func fromPSD(_ key: String) -> BlendMode? {
        switch key {
        case "norm": .normal
        case "mul ": .multiply
        case "scrn": .screen
        case "over": .overlay
        case "dark": .darken
        case "lite": .lighten
        case "div ": .colorDodge
        case "idiv": .colorBurn
        case "sLit": .softLight
        case "hLit": .hardLight
        case "diff": .difference
        case "smud": .exclusion
        default: nil
        }
    }
}
