// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

struct PickerHSB: Equatable, Sendable {
    var hue: Double
    var saturation: Double
    var brightness: Double

    init(hue: Double, saturation: Double, brightness: Double) {
        let wrapped = hue.truncatingRemainder(dividingBy: 360)
        self.hue = wrapped < 0 ? wrapped + 360 : wrapped
        self.saturation = min(1, max(0, saturation))
        self.brightness = min(1, max(0, brightness))
    }

    init(color: RGBA) {
        let red = Double(color.r) / 255
        let green = Double(color.g) / 255
        let blue = Double(color.b) / 255
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        brightness = maxValue
        saturation = maxValue == 0 ? 0 : delta / maxValue
        if delta == 0 {
            hue = 0
        } else if maxValue == red {
            hue = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
        } else if maxValue == green {
            hue = 60 * (((blue - red) / delta) + 2)
        } else {
            hue = 60 * (((red - green) / delta) + 4)
        }
        if hue < 0 { hue += 360 }
    }

    var color: RGBA {
        if hue >= 359.999 { return PickerHSB(hue: 0, saturation: saturation, brightness: brightness).color }
        let chroma = brightness * saturation
        let sector = hue / 60
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let match = brightness - chroma
        let redPart: Double
        let greenPart: Double
        let bluePart: Double
        switch Int(sector) {
        case 0: (redPart, greenPart, bluePart) = (chroma, x, 0)
        case 1: (redPart, greenPart, bluePart) = (x, chroma, 0)
        case 2: (redPart, greenPart, bluePart) = (0, chroma, x)
        case 3: (redPart, greenPart, bluePart) = (0, x, chroma)
        case 4: (redPart, greenPart, bluePart) = (x, 0, chroma)
        default: (redPart, greenPart, bluePart) = (chroma, 0, x)
        }
        return RGBA(r: Self.byte(redPart + match), g: Self.byte(greenPart + match), b: Self.byte(bluePart + match), a: 255)
    }

    private static func byte(_ channel: Double) -> UInt8 {
        UInt8(clamping: Int((channel * 255).rounded()))
    }
}

extension RGBA {
    var hex: String {
        String(format: "%02X%02X%02X", r, g, b)
    }

    init?(hex raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 3 || text.count == 6, text.allSatisfy(\.isHexDigit) else { return nil }
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard let value = UInt32(text, radix: 16) else { return nil }
        self.init(
            r: UInt8((value >> 16) & 0xff),
            g: UInt8((value >> 8) & 0xff),
            b: UInt8(value & 0xff),
            a: 255
        )
    }
}

enum ColorPalette {
    static let swatches: [RGBA] = [
        .black,
        RGBA(r: 128, g: 128, b: 128, a: 255),
        .white,
        .red,
        RGBA(r: 255, g: 128, b: 0, a: 255),
        RGBA(r: 255, g: 255, b: 0, a: 255),
        .green,
        RGBA(r: 0, g: 255, b: 255, a: 255),
        .blue,
        RGBA(r: 128, g: 0, b: 255, a: 255),
        RGBA(r: 255, g: 0, b: 255, a: 255),
        RGBA(r: 128, g: 64, b: 0, a: 255),
    ]

    private static let storageKey = "ptu.recentColors"
    private static let limit = 8

    static func recent() -> [RGBA] {
        let stored = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return stored.compactMap { RGBA(hex: $0) }
    }

    static func remember(_ color: RGBA) {
        let opaque = color.opaque
        var colors = recent().filter { $0.hex != opaque.hex }
        colors.insert(opaque, at: 0)
        if colors.count > limit { colors = Array(colors.prefix(limit)) }
        UserDefaults.standard.set(colors.map(\.hex), forKey: storageKey)
    }
}
