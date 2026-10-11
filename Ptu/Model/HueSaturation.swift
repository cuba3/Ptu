// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

enum ColorRange: String, CaseIterable, Sendable, Hashable, Codable, Identifiable {
    case master
    case reds
    case yellows
    case greens
    case cyans
    case blues
    case magentas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .master: L10n.Adjust.rangeMaster
        case .reds: L10n.Adjust.rangeReds
        case .yellows: L10n.Adjust.rangeYellows
        case .greens: L10n.Adjust.rangeGreens
        case .cyans: L10n.Adjust.rangeCyans
        case .blues: L10n.Adjust.rangeBlues
        case .magentas: L10n.Adjust.rangeMagentas
        }
    }

    var defaultBand: HueBand {
        switch self {
        case .master: HueBand(falloffStart: 0, rangeStart: 0, rangeEnd: 360, falloffEnd: 360)
        case .reds: HueBand(falloffStart: 315, rangeStart: 345, rangeEnd: 15, falloffEnd: 45)
        case .yellows: HueBand(falloffStart: 15, rangeStart: 45, rangeEnd: 75, falloffEnd: 105)
        case .greens: HueBand(falloffStart: 75, rangeStart: 105, rangeEnd: 135, falloffEnd: 165)
        case .cyans: HueBand(falloffStart: 135, rangeStart: 165, rangeEnd: 195, falloffEnd: 225)
        case .blues: HueBand(falloffStart: 195, rangeStart: 225, rangeEnd: 255, falloffEnd: 285)
        case .magentas: HueBand(falloffStart: 255, rangeStart: 285, rangeEnd: 315, falloffEnd: 345)
        }
    }

    static let colorRanges = ColorRange.allCases.filter { $0 != .master }
}

struct HueBand: Equatable, Sendable, Codable {
    var falloffStart: Double
    var rangeStart: Double
    var rangeEnd: Double
    var falloffEnd: Double

    static func forward(_ from: Double, _ to: Double) -> Double {
        let delta = (to - from).truncatingRemainder(dividingBy: 360)
        return delta < 0 ? delta + 360 : delta
    }

    func weight(of hue: Double) -> Double {
        let span = Self.forward(falloffStart, falloffEnd)
        guard span > 0 else { return 1 }
        let position = Self.forward(falloffStart, hue)
        guard position <= span else { return 0 }
        let rampIn = Self.forward(falloffStart, rangeStart)
        let plateauEnd = Self.forward(falloffStart, rangeEnd)
        if position < rampIn { return rampIn > 0 ? position / rampIn : 1 }
        if position <= plateauEnd { return 1 }
        let rampOut = span - plateauEnd
        return rampOut > 0 ? (span - position) / rampOut : 1
    }
}

struct RangeAdjustment: Equatable, Sendable, Codable {
    var hue: Double = 0
    var saturation: Double = 0
    var lightness: Double = 0
}

struct HueSaturationSettings: Equatable, Sendable, Codable {
    var range: ColorRange = .master
    var colorize = false
    var invertRange = false
    var adjustments: [ColorRange: RangeAdjustment] = [:]
    var bands: [ColorRange: HueBand] = Dictionary(uniqueKeysWithValues: ColorRange.allCases.map { ($0, $0.defaultBand) })

    init(hue: Double = 0, saturation: Double = 0, lightness: Double = 0, colorize: Bool = false, range: ColorRange = .master) {
        self.range = range
        self.colorize = colorize
        if hue != 0 || saturation != 0 || lightness != 0 || colorize {
            var created = RangeAdjustment()
            created.hue = hue
            created.saturation = saturation
            created.lightness = lightness
            adjustments[range] = created
        }
    }

    var hue: Double {
        get { adjustments[range]?.hue ?? 0 }
        set { adjustments[range, default: RangeAdjustment()].hue = newValue }
    }

    var saturation: Double {
        get { adjustments[range]?.saturation ?? 0 }
        set { adjustments[range, default: RangeAdjustment()].saturation = newValue }
    }

    var lightness: Double {
        get { adjustments[range]?.lightness ?? 0 }
        set { adjustments[range, default: RangeAdjustment()].lightness = newValue }
    }

    var isIdentity: Bool {
        !colorize && adjustments.values.allSatisfy { $0 == RangeAdjustment() }
    }

    func weight(of colorRange: ColorRange, hue: Double) -> Double {
        guard colorRange != .master else { return 1 }
        let weight = (bands[colorRange] ?? colorRange.defaultBand).weight(of: hue)
        return invertRange && colorRange == range ? 1 - weight : weight
    }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        guard !isIdentity else { return buffer }
        let response = hueResponse()
        return PixelMath.mapColors(buffer) { r, g, b, _, _ in
            let adjusted = Self.adjust(red: r, green: g, blue: b, settings: self, response: response)
            r = adjusted.red
            g = adjusted.green
            b = adjusted.blue
        }
    }

    private func hueResponse() -> [(shift: Double, saturation: Double, lightness: Double)] {
        (0...360).map { degree in
            var response = (shift: 0.0, saturation: 0.0, lightness: 0.0)
            for (colorRange, adjustment) in adjustments where adjustment != RangeAdjustment() {
                let weight = weight(of: colorRange, hue: Double(degree))
                guard weight > 0 else { continue }
                response.shift += adjustment.hue * weight
                response.saturation += adjustment.saturation * weight
                response.lightness += adjustment.lightness * weight
            }
            return response
        }
    }

    static func adjust(
        red: Double,
        green: Double,
        blue: Double,
        settings: HueSaturationSettings,
        response: [(shift: Double, saturation: Double, lightness: Double)]
    ) -> (red: Double, green: Double, blue: Double) {
        var (hue, saturation, lightness) = PixelMath.rgbToHSL(red, green, blue)
        let lightnessAmount: Double
        if settings.colorize {
            hue = settings.hue.truncatingRemainder(dividingBy: 360)
            if hue < 0 { hue += 360 }
            saturation = min(1, max(0, settings.saturation / 100))
            lightnessAmount = settings.lightness / 100
        } else {
            let sampled = response[min(response.count - 1, max(0, Int(hue.rounded())))]
            lightnessAmount = sampled.lightness / 100
            hue = (hue + sampled.shift).truncatingRemainder(dividingBy: 360)
            if hue < 0 { hue += 360 }
            saturation = adjustedSaturation(saturation, by: sampled.saturation)
        }
        let amount = min(1, max(-1, lightnessAmount))
        lightness = amount >= 0 ? lightness + (1 - lightness) * amount : lightness * (1 + amount)
        let rgb = PixelMath.hslToRGB(h: hue, s: saturation, l: min(1, max(0, lightness)))
        return (red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    static func adjustedSaturation(_ saturation: Double, by amount: Double) -> Double {
        let amount = min(1, max(-1, amount / 100))
        guard amount > 0 else { return max(0, saturation * (1 + amount)) }
        return amount >= 1 ? (saturation > 0 ? 1 : 0) : min(1, saturation / (1 - amount))
    }
}
