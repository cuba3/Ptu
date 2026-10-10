// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

/// Premultiplied layer images. A dirty rectangle updates only those pixels; the rest stay cached.
final class LayerImageCache {
    private struct Entry {
        var width: Int
        var height: Int
        var bytes: [UInt8]
        var image: CGImage?
    }

    private var entries: [UUID: Entry] = [:]

    func invalidate() {
        entries.removeAll()
    }

    func prepare(_ layer: PixelLayer, dirty: CGRect?) {
        let width = layer.buffer.width
        let height = layer.buffer.height
        if var entry = entries[layer.id], entry.width == width, entry.height == height {
            layer.buffer.premultiply(into: &entry.bytes, rect: dirty)
            entry.image = nil
            entries[layer.id] = entry
            return
        }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        layer.buffer.premultiply(into: &bytes, rect: nil)
        entries[layer.id] = Entry(width: width, height: height, bytes: bytes, image: nil)
    }

    func image(for layer: PixelLayer) -> CGImage? {
        if entries[layer.id]?.width != layer.buffer.width || entries[layer.id]?.height != layer.buffer.height {
            prepare(layer, dirty: nil)
        }
        if let image = entries[layer.id]?.image {
            return image
        }
        guard var entry = entries[layer.id] else { return nil }
        entry.image = Self.image(bytes: entry.bytes, width: entry.width, height: entry.height)
        entries[layer.id] = entry
        return entry.image
    }

    private static func image(bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        let data = Data(bytes) as CFData
        guard let provider = CGDataProvider(data: data),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
