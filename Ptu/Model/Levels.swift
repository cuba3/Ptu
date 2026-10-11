// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

enum LevelsChannel: String, CaseIterable, Sendable, Codable, Identifiable {
    case rgb
    case red
    case green
    case blue

    var id: String { rawValue }

    var index: Int {
        switch self {
        case .rgb: 0
        case .red: 1
        case .green: 2
        case .blue: 3
        }
    }

    var title: String {
        switch self {
        case .rgb: L10n.Adjust.channelRGB
        case .red: L10n.Adjust.channelRed
        case .green: L10n.Adjust.channelGreen
        case .blue: L10n.Adjust.channelBlue
        }
    }
}

struct LevelRange: Equatable, Sendable, Codable {
    var black: Double = 0
    var gamma: Double = 1
    var white: Double = 255
    var outputBlack: Double = 0
    var outputWhite: Double = 255

    var normalized: Self {
        var result = self
        result.black = PixelMath.clamp(black, 0...254, 0)
        result.white = PixelMath.clamp(white, (result.black + 1)...255, 255)
        result.gamma = PixelMath.clamp(gamma, 0.1...9.99, 1)
        result.outputBlack = PixelMath.clamp(outputBlack, 0...255, 0)
        result.outputWhite = PixelMath.clamp(outputWhite, 0...255, 255)
        return result
    }

    func apply(_ value: Double) -> Double {
        let s = normalized
        let input = min(1, max(0, (value * 255 - s.black) / (s.white - s.black)))
        return (s.outputBlack + pow(input, 1 / s.gamma) * (s.outputWhite - s.outputBlack)) / 255
    }
}

struct LevelsSettings: Equatable, Sendable, Codable {
    var channel: LevelsChannel = .rgb
    var ranges = Array(repeating: LevelRange(), count: 4)

    var current: LevelRange {
        get { ranges[channel.index] }
        set { ranges[channel.index] = newValue.normalized }
    }

    var isIdentity: Bool {
        ranges.allSatisfy { $0.normalized == LevelRange() }
    }

    /// Individual channels, then the composite RGB adjustment.
    func apply(_ value: Double, channel: LevelsChannel) -> Double {
        ranges[0].apply(ranges[channel.index].apply(value))
    }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        let settings = normalized
        if settings.isIdentity { return buffer }
        let tables = [LevelsChannel.red, .green, .blue].map { channel in
            (0...255).map { PixelMath.byte(settings.apply(Double($0) / 255, channel: channel)) }
        }
        var result = buffer
        result.updateEach { _, _, pixel in
            guard pixel.a > 0 else { return }
            pixel.r = tables[0][Int(pixel.r)]
            pixel.g = tables[1][Int(pixel.g)]
            pixel.b = tables[2][Int(pixel.b)]
        }
        return result
    }

    var normalized: Self {
        var result = self
        result.ranges = ranges.map(\.normalized)
        if result.ranges.count != 4 {
            result.ranges = Array(repeating: LevelRange(), count: 4)
        }
        return result
    }
}
