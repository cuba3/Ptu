// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit

struct RGBA: Equatable, Sendable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8

    static let clear = RGBA(r: 0, g: 0, b: 0, a: 0)
    static let white = RGBA(r: 255, g: 255, b: 255, a: 255)
    static let black = RGBA(r: 0, g: 0, b: 0, a: 255)
    static let red = RGBA(r: 255, g: 0, b: 0, a: 255)
    static let green = RGBA(r: 0, g: 255, b: 0, a: 255)
    static let blue = RGBA(r: 0, g: 0, b: 255, a: 255)

    var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(nsColor: NSColor) {
        guard let converted = nsColor.usingColorSpace(.sRGB) else {
            self = .black
            return
        }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        r = Self.byte(red)
        g = Self.byte(green)
        b = Self.byte(blue)
        a = Self.byte(alpha)
    }

    var opaque: RGBA {
        RGBA(r: r, g: g, b: b, a: 255)
    }

    private static func byte(_ channel: CGFloat) -> UInt8 {
        let scaled = Int((channel * 255).rounded())
        return UInt8(clamping: scaled)
    }
}
