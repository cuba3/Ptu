// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

/// Reads 8-bit RGB Photoshop `.psd` and `.psb` files: header, resolution resource,
/// layer records, PackBits, and section dividers. Text, vectors, masks, and adjustments
/// are classified so the builder can report them; they are not reconstructed as live objects.
enum PSDReader {
    static func matches(_ data: Data) -> Bool {
        data.count >= 4 && data.prefix(4) == Data("8BPS".utf8)
    }

    static func read(_ data: Data, remainingPixels: Int = PSDLimits.documentPixelBudget) throws -> PSDDocument {
        var cursor = PSDCursor(data: data)
        guard try cursor.string(4) == "8BPS" else { throw PSDError.truncated }
        let version = try cursor.u16()
        guard version == 1 || version == 2 else { throw PSDError.unsupportedVersion }
        let isPSB = version == 2
        try cursor.skip(6)
        _ = try cursor.u16()
        let canvasHeight = Int(try cursor.u32())
        let canvasWidth = Int(try cursor.u32())
        let depth = try cursor.u16()
        let mode = try cursor.u16()
        guard (1...PSDLimits.maxSide).contains(canvasWidth),
              (1...PSDLimits.maxSide).contains(canvasHeight),
              canvasWidth * canvasHeight <= PSDLimits.maxSurfacePixels else {
            throw PSDError.tooLarge
        }
        guard depth == 8 else { throw PSDError.unsupportedDepth }
        guard mode == 3 else { throw PSDError.unsupportedColorMode }
        try cursor.skip(Int(try cursor.u32()))
        let resourcesLength = Int(try cursor.u32())
        let resourcesEnd = cursor.offset + resourcesLength
        var resolution = 72.0
        while cursor.offset + 12 <= resourcesEnd {
            let signature = try cursor.string(4)
            guard signature == "8BIM" else { break }
            let id = try cursor.u16()
            let nameLength = Int(try cursor.u8())
            try cursor.skip(nameLength)
            if (nameLength + 1) % 2 == 1 { try cursor.skip(1) }
            let length = Int(try cursor.u32())
            let dataStart = cursor.offset
            if id == 1005, length >= 4 {
                resolution = Double(try cursor.u32()) / 65536
                if !resolution.isFinite || resolution < 1 { resolution = 72 }
                resolution = min(9600, max(1, resolution))
            }
            cursor.offset = dataStart + length
            if length % 2 == 1 { try cursor.skip(1) }
        }
        cursor.offset = resourcesEnd
        let layerSection = try checkedLength(isPSB ? cursor.u64() : UInt64(cursor.u32()))
        let layerSectionEnd = cursor.offset + layerSection
        guard layerSection >= 4 else {
            return PSDDocument(width: canvasWidth, height: canvasHeight, resolution: resolution, layers: [])
        }
        let layerInfoLength = try checkedLength(isPSB ? cursor.u64() : UInt64(cursor.u32()))
        _ = layerInfoLength
        let rawCount = try cursor.i16()
        let count = abs(Int(rawCount))
        guard count <= 10_000 else { throw PSDError.tooLarge }
        var raw = [RawLayer]()
        raw.reserveCapacity(count)
        for _ in 0..<count { raw.append(try readRecord(&cursor, isPSB: isPSB)) }
        if !fitsBudget(raw, remainingPixels: remainingPixels) {
            for index in raw.indices {
                cropToCanvas(&raw[index], width: canvasWidth, height: canvasHeight)
            }
            guard fitsBudget(raw, remainingPixels: remainingPixels) else { throw PSDError.tooLarge }
        }
        var usedPixels = 0
        for index in raw.indices {
            try decodeChannels(&cursor, layer: &raw[index], remainingPixels: remainingPixels - usedPixels, isPSB: isPSB)
            if let image = raw[index].image { usedPixels += image.width * image.height }
        }
        cursor.offset = layerSectionEnd
        return PSDDocument(
            width: canvasWidth,
            height: canvasHeight,
            resolution: resolution,
            layers: try assemble(raw, canvas: CGSize(width: canvasWidth, height: canvasHeight))
        )
    }

    private struct RawLayer {
        var name = ""
        var top = 0, left = 0, bottom = 0, right = 0
        var sourceTop = 0, sourceLeft = 0, sourceBottom = 0, sourceRight = 0
        var opacity: UInt8 = 255
        var fill: UInt8 = 255
        var clipping = false
        var hidden = false
        var blendKey = "norm"
        var channels: [(id: Int, length: Int)] = []
        var extra: [String: Data] = [:]
        var maskTop = 0, maskLeft = 0, maskBottom = 0, maskRight = 0
        var sourceMaskTop = 0, sourceMaskLeft = 0, sourceMaskBottom = 0, sourceMaskRight = 0
        var maskDefault: UInt8 = 255
        var maskDisabled = false
        var hasMask = false
        var section: Int?
        var image: CGImage?
        var imageCrop: PSDCrop?
        var maskCrop: PSDCrop?
        var cropped = false
    }

    private static let psbLargeAdditionalInfoKeys: Set<String> = [
        "LMsk", "Lr16", "Lr32", "Layr", "Mt16", "Mt32", "Mtrn", "Alph", "FMsk", "lnk2", "FEid", "FXid", "PxSD",
    ]

    private static let adjustmentKeys: Set<String> = [
        "levl", "curv", "hue2", "hue ", "expA", "grdm", "brit", "blnc", "nvrt",
        "thrs", "post", "mixr", "selc", "blwh", "phfl", "vibA",
    ]

    private static func checkedLength(_ value: UInt64) throws -> Int {
        guard value <= UInt64(Int.max) else { throw PSDError.tooLarge }
        return Int(value)
    }

    private static func readRecord(_ cursor: inout PSDCursor, isPSB: Bool) throws -> RawLayer {
        var layer = RawLayer()
        layer.top = Int(try cursor.i32())
        layer.left = Int(try cursor.i32())
        layer.bottom = Int(try cursor.i32())
        layer.right = Int(try cursor.i32())
        layer.sourceTop = layer.top
        layer.sourceLeft = layer.left
        layer.sourceBottom = layer.bottom
        layer.sourceRight = layer.right
        let channelCount = Int(try cursor.u16())
        guard channelCount <= 56 else { throw PSDError.tooLarge }
        for _ in 0..<channelCount {
            let id = Int(try cursor.i16())
            let length = try checkedLength(isPSB ? cursor.u64() : UInt64(cursor.u32()))
            layer.channels.append((id, length))
        }
        guard try cursor.string(4) == "8BIM" else { throw PSDError.truncated }
        layer.blendKey = try cursor.string(4)
        layer.opacity = try cursor.u8()
        layer.clipping = try cursor.u8() != 0
        let flags = try cursor.u8()
        layer.hidden = (flags & 2) != 0
        try cursor.skip(1)
        let extraLength = Int(try cursor.u32())
        let extraEnd = cursor.offset + extraLength
        let maskLength = Int(try cursor.u32())
        let maskEnd = cursor.offset + maskLength
        if maskLength >= 20 {
            layer.hasMask = true
            layer.maskTop = Int(try cursor.i32())
            layer.maskLeft = Int(try cursor.i32())
            layer.maskBottom = Int(try cursor.i32())
            layer.maskRight = Int(try cursor.i32())
            layer.sourceMaskTop = layer.maskTop
            layer.sourceMaskLeft = layer.maskLeft
            layer.sourceMaskBottom = layer.maskBottom
            layer.sourceMaskRight = layer.maskRight
            layer.maskDefault = try cursor.u8()
            let maskFlags = try cursor.u8()
            layer.maskDisabled = (maskFlags & 2) != 0
        }
        cursor.offset = maskEnd
        let ranges = Int(try cursor.u32())
        try cursor.skip(ranges)
        let nameCount = Int(try cursor.u8())
        let nameBytes = try cursor.bytes(nameCount)
        layer.name = String(bytes: nameBytes, encoding: .macOSRoman) ?? String(bytes: nameBytes, encoding: .isoLatin1) ?? "Layer"
        let namePad = (4 - ((nameCount + 1) % 4)) % 4
        try cursor.skip(namePad)
        while cursor.offset + 12 <= extraEnd {
            let signature = try cursor.string(4)
            guard signature == "8BIM" || signature == "8B64" else { break }
            let key = try cursor.string(4)
            let length: Int
            if signature == "8B64" || (isPSB && psbLargeAdditionalInfoKeys.contains(key)) {
                guard cursor.offset + 8 <= extraEnd else { break }
                length = try checkedLength(cursor.u64())
            } else {
                length = Int(try cursor.u32())
            }
            let payload = try cursor.bytes(length)
            if length % 2 == 1 { try cursor.skip(1) }
            layer.extra[key] = payload
            if key == "luni", let unicode = unicodeName(payload) { layer.name = unicode }
            if key == "iOpa", let fill = payload.first { layer.fill = fill }
            if key == "lsct" || key == "lsdk", payload.count >= 4 {
                layer.section = Int(u32(payload, 0))
            }
        }
        cursor.offset = extraEnd
        return layer
    }

    private static func unicodeName(_ data: Data) -> String? {
        guard data.count >= 4 else { return nil }
        let count = Int(u32(data, 0))
        guard count > 0, data.count >= 4 + count * 2 else { return nil }
        var units = [UInt16]()
        units.reserveCapacity(count)
        for index in 0..<count {
            let hi = data[4 + index * 2], lo = data[5 + index * 2]
            units.append(UInt16(hi) << 8 | UInt16(lo))
        }
        return String(utf16CodeUnits: units, count: count).trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
    }

    private static let unpackedChannelIDs: Set<Int> = [-1, 0, 1, 2, -2]

    private static func fitsBudget(_ layers: [RawLayer], remainingPixels: Int) -> Bool {
        var usedPixels = 0
        for layer in layers {
            let width = max(0, layer.right - layer.left)
            let height = max(0, layer.bottom - layer.top)
            let maskWidth = max(0, layer.maskRight - layer.maskLeft)
            let maskHeight = max(0, layer.maskBottom - layer.maskTop)
            guard fitsBudget(
                width: width,
                height: height,
                maskWidth: maskWidth,
                maskHeight: maskHeight,
                hasMask: layer.hasMask,
                remainingPixels: remainingPixels - usedPixels
            ) else { return false }
            if width > 0, height > 0 { usedPixels += width * height }
        }
        return true
    }

    private static func fitsBudget(
        width: Int,
        height: Int,
        maskWidth: Int,
        maskHeight: Int,
        hasMask: Bool,
        remainingPixels: Int
    ) -> Bool {
        let budget = max(0, remainingPixels)
        if width > 0, height > 0,
           !(width <= PSDLimits.maxSide && height <= PSDLimits.maxSide && width * height <= budget) { return false }
        if hasMask, maskWidth > 0, maskHeight > 0,
           !(maskWidth <= PSDLimits.maxSide && maskHeight <= PSDLimits.maxSide && maskWidth * maskHeight <= budget) { return false }
        return true
    }

    private static func cropToCanvas(_ layer: inout RawLayer, width: Int, height: Int) {
        let imageCrop = crop(left: layer.left, top: layer.top, right: layer.right, bottom: layer.bottom, canvasWidth: width, canvasHeight: height)
        if imageCrop.x != 0 || imageCrop.y != 0 || imageCrop.width != layer.right - layer.left || imageCrop.height != layer.bottom - layer.top {
            layer.left += imageCrop.x
            layer.top += imageCrop.y
            layer.right = layer.left + imageCrop.width
            layer.bottom = layer.top + imageCrop.height
            layer.imageCrop = imageCrop
            layer.cropped = true
        }
        guard layer.hasMask else { return }
        let maskCrop = crop(
            left: layer.maskLeft,
            top: layer.maskTop,
            right: layer.maskRight,
            bottom: layer.maskBottom,
            canvasWidth: width,
            canvasHeight: height
        )
        if maskCrop.x != 0 || maskCrop.y != 0 || maskCrop.width != layer.maskRight - layer.maskLeft || maskCrop.height != layer.maskBottom - layer.maskTop {
            layer.maskLeft += maskCrop.x
            layer.maskTop += maskCrop.y
            layer.maskRight = layer.maskLeft + maskCrop.width
            layer.maskBottom = layer.maskTop + maskCrop.height
            layer.maskCrop = maskCrop
            layer.cropped = true
        }
    }

    private static func crop(left: Int, top: Int, right: Int, bottom: Int, canvasWidth: Int, canvasHeight: Int) -> PSDCrop {
        let croppedLeft = min(canvasWidth, max(0, left))
        let croppedTop = min(canvasHeight, max(0, top))
        let croppedRight = max(croppedLeft, min(canvasWidth, right))
        let croppedBottom = max(croppedTop, min(canvasHeight, bottom))
        return PSDCrop(
            x: croppedLeft - left,
            y: croppedTop - top,
            width: croppedRight - croppedLeft,
            height: croppedBottom - croppedTop
        )
    }

    private static func decodeChannels(_ cursor: inout PSDCursor, layer: inout RawLayer, remainingPixels: Int, isPSB: Bool) throws {
        var planes: [Int: [UInt8]] = [:]
        let width = max(0, layer.right - layer.left)
        let height = max(0, layer.bottom - layer.top)
        let maskWidth = max(0, layer.maskRight - layer.maskLeft)
        let maskHeight = max(0, layer.maskBottom - layer.maskTop)
        guard fitsBudget(
            width: width,
            height: height,
            maskWidth: maskWidth,
            maskHeight: maskHeight,
            hasMask: layer.hasMask,
            remainingPixels: remainingPixels
        ) else { throw PSDError.tooLarge }
        let sourceWidth = max(0, layer.sourceRight - layer.sourceLeft)
        let sourceHeight = max(0, layer.sourceBottom - layer.sourceTop)
        let sourceMaskWidth = max(0, layer.sourceMaskRight - layer.sourceMaskLeft)
        let sourceMaskHeight = max(0, layer.sourceMaskBottom - layer.sourceMaskTop)
        for channel in layer.channels {
            let start = cursor.offset
            defer { cursor.offset = start + max(0, channel.length) }
            guard unpackedChannelIDs.contains(channel.id), channel.length >= 2 else { continue }
            let compression = Int(try cursor.u16())
            let payload = try cursor.bytes(channel.length - 2)
            let isMask = channel.id == -2
            let sourceW = isMask ? sourceMaskWidth : sourceWidth
            let sourceH = isMask ? sourceMaskHeight : sourceHeight
            let targetW = isMask ? maskWidth : width
            let targetH = isMask ? maskHeight : height
            let crop = isMask ? layer.maskCrop : layer.imageCrop
            if targetW > 0, targetH > 0 {
                planes[channel.id] = try PSDChannelCoder.decode(
                    compression: compression,
                    width: sourceW,
                    height: sourceH,
                    data: payload,
                    largeDocument: isPSB,
                    crop: crop
                )
            }
        }
        guard width > 0, height > 0 else { return }
        let opaque = [UInt8](repeating: 255, count: width * height)
        let black = [UInt8](repeating: 0, count: width * height)
        let red = planes[0] ?? black
        let green = planes[1] ?? black
        let blue = planes[2] ?? black
        let alpha = planes[-1] ?? opaque
        guard red.count >= width * height, green.count >= width * height,
              blue.count >= width * height, alpha.count >= width * height else {
            throw PSDError.truncated
        }
        layer.image = try PSDChannelCoder.rgbaImage(width: width, height: height, red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func assemble(_ raw: [RawLayer], canvas: CGSize) throws -> [PSDRecord] {
        var result: [PSDRecord] = []
        var groups: [UUID] = []
        for layer in raw {
            if layer.section == 3 {
                groups.append(UUID())
                continue
            }
            let isGroup = layer.section == 1 || layer.section == 2
            let id = isGroup ? (groups.popLast() ?? UUID()) : UUID()
            var record = PSDRecord(id: id, name: layer.name.isEmpty ? "Layer" : layer.name)
            record.parentID = groups.last
            record.isGroup = isGroup
            record.isVisible = !layer.hidden
            record.blendKey = layer.blendKey
            record.clipping = layer.clipping
            record.kind = kind(layer, isGroup: isGroup)
            record.croppedToCanvas = layer.cropped
            record.hasMask = layer.hasMask && !layer.maskDisabled
            record.hasEffects = layer.extra.keys.contains { ["lfx2", "lrFX", "lmfx"].contains($0) }
            if record.hasEffects, layer.fill != 255 {
                record.opacity = Double(layer.opacity) / 255
            } else {
                record.opacity = (Double(layer.opacity) / 255) * (Double(layer.fill) / 255)
            }
            record.bounds = isGroup
                ? CGRect(origin: .zero, size: canvas)
                : CGRect(
                    x: layer.left,
                    y: layer.top,
                    width: max(0, layer.right - layer.left),
                    height: max(0, layer.bottom - layer.top)
                )
            record.image = isGroup ? nil : layer.image
            result.append(record)
        }
        guard groups.isEmpty else { throw PSDError.truncated }
        return result
    }

    private static func kind(_ layer: RawLayer, isGroup: Bool) -> PSDLayerKind {
        if isGroup { return .group }
        if layer.extra.keys.contains(where: { ["TySh", "tySh", "txt2"].contains($0) }) { return .text }
        if layer.extra.keys.contains(where: { ["vmsk", "vsms", "vogk"].contains($0) }) { return .vector }
        if layer.extra.keys.contains(where: { ["SoLd", "SoLE"].contains($0) }) { return .smartObject }
        if layer.extra.keys.contains(where: { ["lfx2", "lrFX", "lmfx"].contains($0) }) { return .effects }
        if layer.extra.keys.contains(where: { adjustmentKeys.contains($0) }) { return .adjustment }
        return .raster
    }

    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
    }
}

private struct PSDCursor: Sendable {
    let data: Data
    var offset = 0

    mutating func need(_ count: Int) throws {
        guard offset >= 0, offset + count <= data.count else { throw PSDError.truncated }
    }

    mutating func skip(_ count: Int) throws {
        guard count >= 0 else { throw PSDError.truncated }
        try need(count)
        offset += count
    }

    mutating func u8() throws -> UInt8 {
        try need(1)
        defer { offset += 1 }
        return data[offset]
    }

    mutating func u16() throws -> UInt16 {
        try need(2)
        defer { offset += 2 }
        return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    mutating func i16() throws -> Int16 { Int16(bitPattern: try u16()) }

    mutating func u32() throws -> UInt32 {
        try need(4)
        defer { offset += 4 }
        return UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
    }

    mutating func u64() throws -> UInt64 {
        try need(8)
        defer { offset += 8 }
        return UInt64(data[offset]) << 56 | UInt64(data[offset + 1]) << 48 | UInt64(data[offset + 2]) << 40 | UInt64(data[offset + 3]) << 32
            | UInt64(data[offset + 4]) << 24 | UInt64(data[offset + 5]) << 16 | UInt64(data[offset + 6]) << 8 | UInt64(data[offset + 7])
    }

    mutating func i32() throws -> Int32 { Int32(bitPattern: try u32()) }

    mutating func bytes(_ count: Int) throws -> Data {
        try need(count)
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }

    mutating func string(_ count: Int) throws -> String {
        let bytes = try bytes(count)
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}
