// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import CoreImage
import Foundation
import Vision

enum SubjectRemovalResult: Equatable, Sendable {
    /// Vision found no subject, or the caller supplied no mask. Pixels are unchanged.
    case noSubject
    case changed(PixelBuffer)
}

/// Removes the background by keeping Vision's foreground mask.
/// `detector` exists so tests can prove the fallback: a nil mask does not invent pixels.
/// The app default asks Vision. There is no bundled Core ML asset in the reference app.
enum SubjectRemoval {
    static func removeBackground(from buffer: PixelBuffer, detector: ((CGImage) -> [UInt8]?)? = nil) -> SubjectRemovalResult {
        guard let image = buffer.cgImage() else { return .noSubject }
        let detected = detector?(image) ?? (detector == nil ? visionMask(in: image, width: buffer.width, height: buffer.height) : nil)
        guard let detected, detected.count == buffer.width * buffer.height, detected.contains(where: { $0 > 0 }) else {
            return .noSubject
        }
        let guide = luminance(buffer)
        let mask = detected.map { Float($0) / 255 }
        let radius = max(1, min(4, min(buffer.width, buffer.height) / 8))
        let refined = GuidedMatte.filter(mask: mask, guide: guide, width: buffer.width, height: buffer.height, radius: radius, epsilon: 1e-4)
        return .changed(apply(buffer: buffer, subject: refined))
    }

    static func apply(buffer: PixelBuffer, subject: [Float]) -> PixelBuffer {
        guard subject.count == buffer.width * buffer.height else { return buffer }
        var copy = buffer
        copy.updateEach { x, y, pixel in
            let amount = min(1, max(0, subject[y * buffer.width + x]))
            let alpha = Int((CGFloat(pixel.a) * CGFloat(amount)).rounded())
            pixel.a = UInt8(clamping: alpha)
            if pixel.a == 0 {
                pixel = .clear
            }
        }
        return copy
    }

    static func visionMask(in image: CGImage, width: Int, height: Int) -> [UInt8]? {
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
            guard let result = request.results?.first, !result.allInstances.isEmpty else { return nil }
            let scaled = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            return grayBytes(from: scaled, width: width, height: height)
        } catch {
            return nil
        }
    }

    private static func luminance(_ buffer: PixelBuffer) -> [Float] {
        var values = [Float](repeating: 0, count: buffer.width * buffer.height)
        let bytes = buffer.copyBytes()
        for index in 0..<(buffer.width * buffer.height) {
            let offset = index * 4
            let r = Float(bytes[offset])
            let g = Float(bytes[offset + 1])
            let b = Float(bytes[offset + 2])
            values[index] = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
        }
        return values
    }

    private static func grayBytes(from pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> [UInt8]? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        guard let rendered = context.createCGImage(image, from: image.extent) else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height)
        guard let bitmap = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        bitmap.interpolationQuality = .high
        bitmap.draw(rendered, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}
