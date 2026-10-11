// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

/// Straight (non-premultiplied) sRGB 8-bit pixels, origin at the top left.
/// Copies storage only when a shared buffer is mutated.
struct PixelBuffer: Equatable, @unchecked Sendable {
    final class Storage: @unchecked Sendable {
        var bytes: [UInt8]
        let width: Int
        let height: Int

        init(width: Int, height: Int, fill: RGBA) {
            self.width = width
            self.height = height
            let count = width * height * 4
            if fill == .clear {
                bytes = [UInt8](repeating: 0, count: count)
            } else {
                var data = [UInt8](repeating: 0, count: count)
                var offset = 0
                while offset < count {
                    data[offset] = fill.r
                    data[offset + 1] = fill.g
                    data[offset + 2] = fill.b
                    data[offset + 3] = fill.a
                    offset += 4
                }
                bytes = data
            }
        }

        init(copying other: Storage) {
            bytes = other.bytes
            width = other.width
            height = other.height
        }

        init(bytes: [UInt8], width: Int, height: Int) {
            self.bytes = bytes
            self.width = width
            self.height = height
        }
    }

    private var storage: Storage

    var width: Int { storage.width }
    var height: Int { storage.height }

    init(width: Int, height: Int, fill: RGBA) {
        storage = Storage(width: max(1, width), height: max(1, height), fill: fill)
    }

    init(bytes: [UInt8], width: Int, height: Int) {
        precondition(bytes.count == width * height * 4)
        storage = Storage(bytes: bytes, width: width, height: height)
    }

    func sharesStorage(with other: PixelBuffer) -> Bool {
        storage === other.storage
    }

    static func == (lhs: PixelBuffer, rhs: PixelBuffer) -> Bool {
        if lhs.storage === rhs.storage { return true }
        return lhs.storage.width == rhs.storage.width
            && lhs.storage.height == rhs.storage.height
            && lhs.storage.bytes == rhs.storage.bytes
    }

    func copyBytes() -> [UInt8] {
        storage.bytes
    }

    mutating func setBytes(_ bytes: [UInt8]) {
        guard bytes.count == width * height * 4 else { return }
        makeUnique()
        storage.bytes = bytes
    }

    /// Visits every pixel in row-major order, top-left origin. `body` may replace the pixel.
    mutating func updateEach(_ body: (_ x: Int, _ y: Int, _ pixel: inout RGBA) -> Void) {
        makeUnique()
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                var pixel = RGBA(
                    r: storage.bytes[index],
                    g: storage.bytes[index + 1],
                    b: storage.bytes[index + 2],
                    a: storage.bytes[index + 3]
                )
                body(x, y, &pixel)
                storage.bytes[index] = pixel.r
                storage.bytes[index + 1] = pixel.g
                storage.bytes[index + 2] = pixel.b
                storage.bytes[index + 3] = pixel.a
            }
        }
    }

    func pixel(x: Int, y: Int) -> RGBA {
        guard x >= 0, y >= 0, x < width, y < height else { return .clear }
        let index = (y * width + x) * 4
        return RGBA(
            r: storage.bytes[index],
            g: storage.bytes[index + 1],
            b: storage.bytes[index + 2],
            a: storage.bytes[index + 3]
        )
    }

    mutating func blit(_ source: PixelBuffer, atX originX: Int, y originY: Int) {
        makeUnique()
        for row in 0..<source.height {
            let destinationY = originY + row
            guard destinationY >= 0, destinationY < height else { continue }
            for column in 0..<source.width {
                let destinationX = originX + column
                guard destinationX >= 0, destinationX < width else { continue }
                let pixel = source.pixel(x: column, y: row)
                let index = (destinationY * width + destinationX) * 4
                storage.bytes[index] = pixel.r
                storage.bytes[index + 1] = pixel.g
                storage.bytes[index + 2] = pixel.b
                storage.bytes[index + 3] = pixel.a
            }
        }
    }

    /// Replaces each channel by `amount` of `color`. `amount` is 0...1.
    mutating func mixPixel(x: Int, y: Int, color: RGBA, amount: CGFloat) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let coverage = min(max(amount, 0), 1)
        guard coverage > 0 else { return }
        makeUnique()
        let index = (y * width + x) * 4
        let channels = [color.r, color.g, color.b, color.a]
        for channel in 0..<4 {
            let destination = CGFloat(storage.bytes[index + channel])
            let source = CGFloat(channels[channel])
            storage.bytes[index + channel] = UInt8(clamping: Int((destination + (source - destination) * coverage).rounded()))
        }
    }

    mutating func paint(_ color: RGBA, x: Int, y: Int, coverage: CGFloat) {
        guard x >= 0, y >= 0, x < width, y < height, coverage > 0 else { return }
        makeUnique()
        blendOver(x: x, y: y, source: color, coverage: min(coverage, 1))
    }

    mutating func erase(canvasCoverage: [UInt8], canvasWidth: Int, originX: Int, originY: Int) {
        guard canvasWidth > 0, canvasCoverage.count.isMultiple(of: canvasWidth) else { return }
        let canvasHeight = canvasCoverage.count / canvasWidth
        makeUnique()
        for y in 0..<height {
            let canvasY = originY + y
            guard canvasY >= 0, canvasY < canvasHeight else { continue }
            for x in 0..<width {
                let canvasX = originX + x
                guard canvasX >= 0, canvasX < canvasWidth else { continue }
                let coverage = canvasCoverage[canvasY * canvasWidth + canvasX]
                guard coverage > 0 else { continue }
                let index = (y * width + x) * 4
                if coverage >= 255 {
                    storage.bytes[index] = 0
                    storage.bytes[index + 1] = 0
                    storage.bytes[index + 2] = 0
                    storage.bytes[index + 3] = 0
                } else {
                    let keep = CGFloat(255 - coverage) / 255
                    let alpha = Int((CGFloat(storage.bytes[index + 3]) * keep).rounded())
                    storage.bytes[index + 3] = UInt8(clamping: alpha)
                    if alpha == 0 {
                        storage.bytes[index] = 0
                        storage.bytes[index + 1] = 0
                        storage.bytes[index + 2] = 0
                    }
                }
            }
        }
    }

    mutating func setPixel(x: Int, y: Int, rgba: RGBA) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        makeUnique()
        let index = (y * width + x) * 4
        storage.bytes[index] = rgba.r
        storage.bytes[index + 1] = rgba.g
        storage.bytes[index + 2] = rgba.b
        storage.bytes[index + 3] = rgba.a
    }

    mutating func clear(rect: CGRect) {
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let area = rect.standardized.intersection(bounds)
        guard area.width >= 1, area.height >= 1 else { return }
        makeUnique()
        let minX = Int(area.minX.rounded(.down))
        let minY = Int(area.minY.rounded(.down))
        let maxX = min(width, Int(area.maxX.rounded(.up)))
        let maxY = min(height, Int(area.maxY.rounded(.up)))
        for y in minY..<maxY {
            for x in minX..<maxX {
                let index = (y * width + x) * 4
                storage.bytes[index] = 0
                storage.bytes[index + 1] = 0
                storage.bytes[index + 2] = 0
                storage.bytes[index + 3] = 0
            }
        }
    }

    /// Copies the pixel rectangle. `minX`/`minY` are buffer coordinates, top-left origin.
    func cropped(minX: Int, minY: Int, width cropWidth: Int, height cropHeight: Int) -> PixelBuffer {
        let x0 = max(0, minX)
        let y0 = max(0, minY)
        let x1 = min(width, minX + max(cropWidth, 0))
        let y1 = min(height, minY + max(cropHeight, 0))
        let resultWidth = x1 - x0
        let resultHeight = y1 - y0
        guard resultWidth >= 1, resultHeight >= 1 else {
            return PixelBuffer(width: 1, height: 1, fill: .clear)
        }
        var bytes = [UInt8](repeating: 0, count: resultWidth * resultHeight * 4)
        let rowBytes = resultWidth * 4
        for row in 0..<resultHeight {
            let source = ((y0 + row) * width + x0) * 4
            let destination = row * rowBytes
            bytes.replaceSubrange(destination..<(destination + rowBytes), with: storage.bytes[source..<(source + rowBytes)])
        }
        return PixelBuffer(bytes: bytes, width: resultWidth, height: resultHeight)
    }

    /// Writes premultiplied sRGB into `destination`, which is packed top-left RGBA of this buffer's size.
    func premultiply(into destination: inout [UInt8], rect: CGRect?) {
        guard destination.count == width * height * 4 else { return }
        let minX: Int
        let minY: Int
        let maxX: Int
        let maxY: Int
        if let rect {
            let bounds = CGRect(x: 0, y: 0, width: width, height: height)
            let area = rect.standardized.intersection(bounds)
            guard area.width >= 1, area.height >= 1 else { return }
            minX = max(0, Int(floor(area.minX)))
            minY = max(0, Int(floor(area.minY)))
            maxX = min(width, Int(ceil(area.maxX)))
            maxY = min(height, Int(ceil(area.maxY)))
        } else {
            minX = 0
            minY = 0
            maxX = width
            maxY = height
        }
        guard minX < maxX, minY < maxY else { return }
        for y in minY..<maxY {
            for x in minX..<maxX {
                let index = (y * width + x) * 4
                let alpha = storage.bytes[index + 3]
                destination[index + 3] = alpha
                if alpha == 0 {
                    destination[index] = 0
                    destination[index + 1] = 0
                    destination[index + 2] = 0
                } else if alpha == 255 {
                    destination[index] = storage.bytes[index]
                    destination[index + 1] = storage.bytes[index + 1]
                    destination[index + 2] = storage.bytes[index + 2]
                } else {
                    let scale = CGFloat(alpha) / 255
                    destination[index] = UInt8((CGFloat(storage.bytes[index]) * scale).rounded())
                    destination[index + 1] = UInt8((CGFloat(storage.bytes[index + 1]) * scale).rounded())
                    destination[index + 2] = UInt8((CGFloat(storage.bytes[index + 2]) * scale).rounded())
                }
            }
        }
    }

    /// Paints a circular dab. `center` is in buffer pixels, top-left origin.
    /// Returns the changed bounds in buffer space.
    @discardableResult
    mutating func stamp(
        center: CGPoint,
        radius: CGFloat,
        hardness: CGFloat,
        opacity: CGFloat,
        color: RGBA
    ) -> CGRect {
        let paintRadius = max(radius, 0.5)
        let minX = max(0, Int(floor(center.x - paintRadius)))
        let maxX = min(width - 1, Int(ceil(center.x + paintRadius)))
        let minY = max(0, Int(floor(center.y - paintRadius)))
        let maxY = min(height - 1, Int(ceil(center.y + paintRadius)))
        guard minX <= maxX, minY <= maxY else {
            return .null
        }
        makeUnique()
        let inner = paintRadius * min(max(hardness, 0), 1)
        let coverageScale = min(max(opacity, 0), 1)
        for y in minY...maxY {
            for x in minX...maxX {
                let dx = CGFloat(x) + 0.5 - center.x
                let dy = CGFloat(y) + 0.5 - center.y
                let distance = hypot(dx, dy)
                guard distance <= paintRadius else { continue }
                let falloff: CGFloat
                if distance <= inner || inner >= paintRadius {
                    falloff = 1
                } else {
                    falloff = 1 - (distance - inner) / (paintRadius - inner)
                }
                blendOver(x: x, y: y, source: color, coverage: coverageScale * falloff)
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    func cgImage() -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        var premultiplied = storage.bytes
        var offset = 0
        while offset < premultiplied.count {
            let alpha = CGFloat(premultiplied[offset + 3]) / 255
            premultiplied[offset] = UInt8((CGFloat(premultiplied[offset]) * alpha).rounded())
            premultiplied[offset + 1] = UInt8((CGFloat(premultiplied[offset + 1]) * alpha).rounded())
            premultiplied[offset + 2] = UInt8((CGFloat(premultiplied[offset + 2]) * alpha).rounded())
            offset += 4
        }
        let data = Data(premultiplied) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
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

    static func from(cgImage: CGImage) -> PixelBuffer? {
        let imageWidth = cgImage.width
        let imageHeight = cgImage.height
        guard imageWidth > 0, imageHeight > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: imageWidth * imageHeight * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: &bytes,
            width: imageWidth,
            height: imageHeight,
            bitsPerComponent: 8,
            bytesPerRow: imageWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        var offset = 0
        while offset < bytes.count {
            let alpha = bytes[offset + 3]
            if alpha == 0 {
                bytes[offset] = 0
                bytes[offset + 1] = 0
                bytes[offset + 2] = 0
            } else if alpha < 255 {
                bytes[offset] = unpremultiply(bytes[offset], alpha: alpha)
                bytes[offset + 1] = unpremultiply(bytes[offset + 1], alpha: alpha)
                bytes[offset + 2] = unpremultiply(bytes[offset + 2], alpha: alpha)
            }
            offset += 4
        }
        return PixelBuffer(bytes: bytes, width: imageWidth, height: imageHeight)
    }

    private mutating func blendOver(x: Int, y: Int, source: RGBA, coverage: CGFloat) {
        let index = (y * width + x) * 4
        let sourceAlpha = (CGFloat(source.a) / 255) * coverage
        guard sourceAlpha > 0 else { return }
        let destinationAlpha = CGFloat(storage.bytes[index + 3]) / 255
        let outAlpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
        guard outAlpha > 0 else { return }
        let sourceR = CGFloat(source.r) / 255
        let sourceG = CGFloat(source.g) / 255
        let sourceB = CGFloat(source.b) / 255
        let destR = CGFloat(storage.bytes[index]) / 255
        let destG = CGFloat(storage.bytes[index + 1]) / 255
        let destB = CGFloat(storage.bytes[index + 2]) / 255
        let outR = (sourceR * sourceAlpha + destR * destinationAlpha * (1 - sourceAlpha)) / outAlpha
        let outG = (sourceG * sourceAlpha + destG * destinationAlpha * (1 - sourceAlpha)) / outAlpha
        let outB = (sourceB * sourceAlpha + destB * destinationAlpha * (1 - sourceAlpha)) / outAlpha
        storage.bytes[index] = UInt8(clamping: Int((outR * 255).rounded()))
        storage.bytes[index + 1] = UInt8(clamping: Int((outG * 255).rounded()))
        storage.bytes[index + 2] = UInt8(clamping: Int((outB * 255).rounded()))
        storage.bytes[index + 3] = UInt8(clamping: Int((outAlpha * 255).rounded()))
    }

    private mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(copying: storage)
        }
    }

    private static func unpremultiply(_ channel: UInt8, alpha: UInt8) -> UInt8 {
        let value = Int((CGFloat(channel) * 255 / CGFloat(alpha)).rounded())
        return UInt8(clamping: value)
    }
}
