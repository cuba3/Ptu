// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import CoreImage
import Foundation
import Vision

/// Foreground instance under a click, from Vision's instance mask.
/// A miss or a Vision failure returns nil — it does not invent an outline.
enum ObjectSelection {
    static func mask(in buffer: PixelBuffer, at point: CGPoint, edgeOffset: Int) -> [UInt8]? {
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard point.x.isFinite, point.y.isFinite,
              (0..<buffer.width).contains(x), (0..<buffer.height).contains(y),
              let image = buffer.cgImage() else { return nil }
        guard let coarse = instanceMask(in: image, at: point, width: buffer.width, height: buffer.height) else { return nil }
        return adjusted(coarse, width: buffer.width, height: buffer.height, edgeOffset: edgeOffset)
    }

    static func adjusted(_ mask: [UInt8], width: Int, height: Int, edgeOffset: Int) -> [UInt8] {
        var result = mask
        let steps = min(10, abs(edgeOffset))
        guard steps > 0, width > 0, height > 0, mask.count == width * height else { return result }
        for _ in 0..<steps {
            result = edgeOffset > 0 ? eroded(result, width: width, height: height) : dilated(result, width: width, height: height)
        }
        return result
    }

    static func eroded(_ mask: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = mask
        for y in 0..<height {
            for x in 0..<width where mask[y * width + x] != 0 {
                var keep = true
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) where mask[ny * width + nx] == 0 {
                        keep = false
                    }
                }
                result[y * width + x] = keep ? 255 : 0
            }
        }
        return result
    }

    static func dilated(_ mask: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = mask
        for y in 0..<height {
            for x in 0..<width where mask[y * width + x] == 0 {
                var fill = false
                for ny in max(0, y - 1)...min(height - 1, y + 1) {
                    for nx in max(0, x - 1)...min(width - 1, x + 1) where mask[ny * width + nx] != 0 {
                        fill = true
                    }
                }
                if fill { result[y * width + x] = 255 }
            }
        }
        return result
    }

    private static func instanceMask(in image: CGImage, at point: CGPoint, width: Int, height: Int) -> [UInt8]? {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first,
              let index = instanceIndex(in: observation.instanceMask, at: point, imageWidth: width, imageHeight: height),
              observation.allInstances.contains(index) else { return nil }
        do {
            let scaled = try observation.generateScaledMaskForImage(forInstances: IndexSet(integer: index), from: handler)
            guard let bytes = grayBytes(from: scaled, width: width, height: height) else { return nil }
            return bytes.map { $0 >= 128 ? 255 : 0 }
        } catch {
            return nil
        }
    }

    private static func instanceIndex(in pixelBuffer: CVPixelBuffer, at point: CGPoint, imageWidth: Int, imageHeight: Int) -> Int? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0, imageWidth > 0, imageHeight > 0,
              let bytes = grayBytes(from: pixelBuffer, width: width, height: height) else { return nil }
        let x = min(width - 1, max(0, Int((point.x / CGFloat(imageWidth)) * CGFloat(width))))
        let y = min(height - 1, max(0, Int((point.y / CGFloat(imageHeight)) * CGFloat(height))))
        let value = Int(bytes[y * width + x])
        return value == 0 ? nil : value
    }

    private static func grayBytes(from pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> [UInt8]? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        guard let rendered = context.createCGImage(image, from: image.extent) else { return nil }
        return grayBytes(from: rendered, width: width, height: height)
    }

    private static func grayBytes(from image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}
