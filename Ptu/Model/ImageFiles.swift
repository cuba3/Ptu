// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageFiles {
    static func pngData(from image: CGImage, ppi: Double) throws -> Data {
        try destinationData(image: image, type: .png, ppi: ppi, quality: nil)
    }

    static func jpegData(from image: CGImage, ppi: Double, quality: CGFloat = 0.9) throws -> Data {
        try destinationData(image: image, type: .jpeg, ppi: ppi, quality: quality)
    }

    static func decode(_ data: Data) throws -> (buffer: PixelBuffer, ppi: Double) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw DocumentError.unreadable
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let dpi = properties?[kCGImagePropertyDPIWidth] as? Double
        let ppi = (dpi ?? 72) > 0 ? (dpi ?? 72) : 72
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw DocumentError.unreadable
        }
        let extent = image.extent.integral
        guard extent.width >= 1, extent.height >= 1, extent.width <= Double(DocumentModel.maximumSide),
              extent.height <= Double(DocumentModel.maximumSide) else {
            throw DocumentError.unreadable
        }
        let context = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        ])
        guard let rendered = context.createCGImage(image, from: extent),
              let buffer = PixelBuffer.from(cgImage: rendered) else {
            throw DocumentError.unreadable
        }
        return (buffer, min(max(ppi, 1), 2400))
    }

    private static func destinationData(
        image: CGImage,
        type: UTType,
        ppi: Double,
        quality: CGFloat?
    ) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw DocumentError.unreadable
        }
        var properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: ppi,
            kCGImagePropertyDPIHeight: ppi,
        ]
        if let quality {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw DocumentError.unreadable }
        return data as Data
    }
}
