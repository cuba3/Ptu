// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RawDevelopSettings: Equatable, Sendable {
    var exposure: Float = 0
    var temperature: Float = 5000
    var tint: Float = 0
    var boost: Float = 1
    var asShotTemperature: Float = 5000
    var asShotTint: Float = 0

    var isAsShot: Bool {
        exposure == 0 && boost == 1 && temperature == asShotTemperature && tint == asShotTint
    }

    mutating func reset() {
        exposure = 0
        boost = 1
        temperature = asShotTemperature
        tint = asShotTint
    }
}

enum RawImporter {
    private static let context = CIContext(options: [
        .workingFormat: CIFormat.RGBAh,
        .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    ])

    static func matches(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .rawImage)
    }

    static func asShot(_ url: URL) -> RawDevelopSettings? {
        guard let filter = CIRAWFilter(imageURL: url) else { return nil }
        var settings = RawDevelopSettings()
        settings.temperature = filter.neutralTemperature
        settings.tint = filter.neutralTint
        settings.asShotTemperature = filter.neutralTemperature
        settings.asShotTint = filter.neutralTint
        return settings
    }

    static func develop(_ url: URL, settings: RawDevelopSettings) -> PixelBuffer? {
        guard let filter = CIRAWFilter(imageURL: url) else { return nil }
        filter.exposure = settings.exposure
        filter.neutralTemperature = settings.temperature
        filter.neutralTint = settings.tint
        filter.boostAmount = settings.boost
        guard let output = filter.outputImage else { return nil }
        let extent = output.extent.integral
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0, width <= DocumentModel.maximumSide, height <= DocumentModel.maximumSide else { return nil }
        guard let rendered = context.createCGImage(
            output,
            from: extent,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        ) else { return nil }
        return PixelBuffer.from(cgImage: rendered)
    }
}
