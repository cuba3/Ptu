// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreImage
import Foundation

enum CameraRawWhiteBalance: String, CaseIterable, Sendable, Codable, Identifiable {
    case custom
    case auto
    var id: String { rawValue }
}

enum CameraRawGlowStyle: String, CaseIterable, Sendable, Codable, Identifiable {
    case diffusion
    case bloom
    case halation
    var id: String { rawValue }
    var kernelValue: Int {
        switch self {
        case .diffusion: 0
        case .bloom: 1
        case .halation: 2
        }
    }
}

enum CameraRawVignetteStyle: String, CaseIterable, Sendable, Codable, Identifiable {
    case highlightPriority
    case colorPriority
    case paintOverlay
    var id: String { rawValue }
    var kernelValue: Int {
        switch self {
        case .highlightPriority: 0
        case .colorPriority: 1
        case .paintOverlay: 2
        }
    }
}

enum CameraRawProcessVersion: String, CaseIterable, Sendable, Codable, Identifiable {
    case version1
    case version2
    case version3
    case version4
    case version5
    case version6
    var id: String { rawValue }
    var kernelValue: Int {
        switch self {
        case .version1: 1
        case .version2: 2
        case .version3: 3
        case .version4: 4
        case .version5: 5
        case .version6: 6
        }
    }
}

struct CameraRawCurveSettings: Equatable, Sendable, Codable {
    var shadows: Double = 0
    var darks: Double = 0
    var lights: Double = 0
    var highlights: Double = 0
    var shadowSplit: Double = 25
    var darkSplit: Double = 50
    var lightSplit: Double = 75
    var rgb = Self.linear
    var red = Self.linear
    var green = Self.linear
    var blue = Self.linear
    var refineSaturation: Double = 0

    static let linear = [CurvePoint(x: 0, y: 0), CurvePoint(x: 1, y: 1)]

    var adjusts: Bool {
        shadows != 0 || darks != 0 || lights != 0 || highlights != 0 || refineSaturation != 0
            || !Self.isLinear(rgb) || !Self.isLinear(red) || !Self.isLinear(green) || !Self.isLinear(blue)
    }

    static func isLinear(_ points: [CurvePoint]) -> Bool {
        points.count == 2 && points[0].x == 0 && points[0].y == 0 && points[1].x == 1 && points[1].y == 1
    }

    func toneTable() -> [Double] {
        (0...255).map { point(parametric(Double($0) / 255), rgb) }
    }

    func channelTable(_ points: [CurvePoint]) -> [Double] {
        (0...255).map { point(Double($0) / 255, points) }
    }

    var normalized: Self {
        var result = self
        result.shadows = PixelMath.clamp(shadows, -100...100, 0)
        result.darks = PixelMath.clamp(darks, -100...100, 0)
        result.lights = PixelMath.clamp(lights, -100...100, 0)
        result.highlights = PixelMath.clamp(highlights, -100...100, 0)
        result.refineSaturation = PixelMath.clamp(refineSaturation, -100...100, 0)
        result.shadowSplit = PixelMath.clamp(shadowSplit, 5...90, 25)
        result.darkSplit = PixelMath.clamp(darkSplit, result.shadowSplit + 2...95, 50)
        result.lightSplit = PixelMath.clamp(lightSplit, result.darkSplit + 2...98, 75)
        return result
    }

    private func parametric(_ tone: Double) -> Double {
        guard shadows != 0 || darks != 0 || lights != 0 || highlights != 0 else { return tone }
        let anchors = (0...32).map { index -> CurvePoint in
            let x = Double(index) / 32
            let bent = Self.bend(Self.bend(x, lower: shadowSplit / 100, shadows, upper: lightSplit / 100, highlights),
                                 lower: darkSplit / 100, darks, upper: darkSplit / 100, lights)
            return CurvePoint(x: x, y: bent)
        }
        return point(tone, anchors)
    }

    private static func bend(_ tone: Double, lower: Double, _ low: Double, upper: Double, _ high: Double) -> Double {
        let strength = 1.66
        if tone < lower, lower > 0 {
            return lower * pow(tone / lower, pow(2, -low / 100 * strength))
        }
        if tone > upper, upper < 1 {
            let rest = 1 - upper
            return 1 - rest * pow((1 - tone) / rest, pow(2, high / 100 * strength))
        }
        return tone
    }

    private func point(_ x: Double, _ points: [CurvePoint]) -> Double {
        var curve = CurvesSettings()
        curve.channels[0] = points.map { CurvePoint(x: $0.x * 255, y: $0.y * 255) }
        guard curve.channels[0].count >= 2 else { return x }
        return curve.value(x * 255, channel: 0) / 255
    }
}

struct CameraRawPointColor: Equatable, Sendable, Codable {
    var hue: Double = 0
    var saturation: Double = 0
    var luminance: Double = 0
    var hueShift: Double = 0
    var saturationShift: Double = 0
    var luminanceShift: Double = 0
    var hueRange: Double = 30
    var saturationRange: Double = 0.4
    var luminanceRange: Double = 0.4
}

struct CameraRawMixerSettings: Equatable, Sendable, Codable {
    var hue = Array(repeating: 0.0, count: 8)
    var saturation = Array(repeating: 0.0, count: 8)
    var luminance = Array(repeating: 0.0, count: 8)
    var points: [CameraRawPointColor] = []

    var adjusts: Bool {
        hue.contains { $0 != 0 } || saturation.contains { $0 != 0 } || luminance.contains { $0 != 0 }
            || points.contains { $0.hueShift != 0 || $0.saturationShift != 0 || $0.luminanceShift != 0 }
    }
}

struct CameraRawGradeWheel: Equatable, Sendable, Codable {
    var hue: Double = 0
    var saturation: Double = 0
    var luminance: Double = 0
}

struct CameraRawGradingSettings: Equatable, Sendable, Codable {
    var shadows = CameraRawGradeWheel()
    var midtones = CameraRawGradeWheel()
    var highlights = CameraRawGradeWheel()
    var global = CameraRawGradeWheel()
    var blending: Double = 50
    var balance: Double = 0

    var wheels: [CameraRawGradeWheel] { [shadows, midtones, highlights, global] }
    var adjusts: Bool { wheels.contains { $0.saturation != 0 || $0.luminance != 0 } }
}

struct CameraRawDetailSettings: Equatable, Sendable, Codable {
    var sharpenAmount: Double = 0
    var sharpenRadius: Double = 10
    var sharpenDetail: Double = 25
    var sharpenMasking: Double = 0
    var noiseLuminance: Double = 0
    var noiseLuminanceDetail: Double = 50
    var noiseLuminanceContrast: Double = 0
    var noiseColor: Double = 0
    var noiseColorDetail: Double = 50
    var noiseColorSmoothness: Double = 50

    var adjusts: Bool { sharpenAmount != 0 || noiseLuminance != 0 || noiseColor != 0 }

    var normalized: Self {
        var result = self
        result.sharpenAmount = PixelMath.clamp(sharpenAmount, 0...150, 0)
        result.sharpenRadius = PixelMath.clamp(sharpenRadius, 0...100, 10)
        result.sharpenDetail = PixelMath.clamp(sharpenDetail, 0...100, 25)
        result.sharpenMasking = PixelMath.clamp(sharpenMasking, 0...100, 0)
        result.noiseLuminance = PixelMath.clamp(noiseLuminance, 0...100, 0)
        result.noiseLuminanceDetail = PixelMath.clamp(noiseLuminanceDetail, 0...100, 50)
        result.noiseLuminanceContrast = PixelMath.clamp(noiseLuminanceContrast, 0...100, 0)
        result.noiseColor = PixelMath.clamp(noiseColor, 0...100, 0)
        result.noiseColorDetail = PixelMath.clamp(noiseColorDetail, 0...100, 50)
        result.noiseColorSmoothness = PixelMath.clamp(noiseColorSmoothness, 0...100, 50)
        return result
    }
}

struct CameraRawOpticsSettings: Equatable, Sendable, Codable {
    var removeChromaticAberration = false
    var enableLensProfile = false
    var profileDistortion: Double = 100
    var profileVignetting: Double = 100
    var distortion: Double = 0
    var purpleAmount: Double = 0
    var purpleHueLow: Double = 270
    var purpleHueHigh: Double = 310
    var greenAmount: Double = 0
    var greenHueLow: Double = 60
    var greenHueHigh: Double = 120
    var vignetteAmount: Double = 0
    var vignetteMidpoint: Double = 50

    var adjusts: Bool {
        removeChromaticAberration || enableLensProfile || distortion != 0 || purpleAmount != 0 || greenAmount != 0 || vignetteAmount != 0
    }

    func distortionK(profileStrength: Double) -> Double {
        let manual = distortion / 100 * profileStrength
        let profile = enableLensProfile ? profileDistortion / 100 * profileStrength : 0
        return manual + profile
    }

    var normalized: Self {
        var result = self
        result.profileDistortion = PixelMath.clamp(profileDistortion, 0...100, 100)
        result.profileVignetting = PixelMath.clamp(profileVignetting, 0...100, 100)
        result.distortion = PixelMath.clamp(distortion, -100...100, 0)
        result.purpleAmount = PixelMath.clamp(purpleAmount, 0...100, 0)
        result.greenAmount = PixelMath.clamp(greenAmount, 0...100, 0)
        result.vignetteAmount = PixelMath.clamp(vignetteAmount, -100...100, 0)
        result.vignetteMidpoint = PixelMath.clamp(vignetteMidpoint, 0...100, 50)
        return result
    }
}

enum CameraRawUprightMode: String, CaseIterable, Sendable, Codable, Identifiable {
    case off
    case guided
    var id: String { rawValue }
}

struct CameraRawGeometryGuide: Equatable, Sendable, Codable {
    var startX: Double = 0
    var startY: Double = 0
    var endX: Double = 0
    var endY: Double = 0
}

struct CameraRawGeometrySettings: Equatable, Sendable, Codable {
    var upright: CameraRawUprightMode = .off
    var vertical: Double = 0
    var horizontal: Double = 0
    var rotate: Double = 0
    var aspect: Double = 0
    var scale: Double = 0
    var offsetX: Double = 0
    var offsetY: Double = 0
    var guides: [CameraRawGeometryGuide] = []

    var adjusts: Bool {
        vertical != 0 || horizontal != 0 || rotate != 0 || aspect != 0 || scale != 0 || offsetX != 0 || offsetY != 0
            || (upright == .guided && guides.contains { hypot($0.endX - $0.startX, $0.endY - $0.startY) > 0.01 })
    }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        guard adjusts, let image = buffer.cgImage() else { return buffer }
        let corrections = effectiveCorrections()
        let corners = outputCorners(width: buffer.width, height: buffer.height, vertical: corrections.vertical, horizontal: corrections.horizontal, rotation: corrections.rotate)
        func vector(_ point: CGPoint) -> CIVector { CIVector(x: point.x, y: point.y) }
        let warped = CIImage(cgImage: image).applyingFilter("CIPerspectiveTransform", parameters: [
            "inputTopLeft": vector(corners[0]),
            "inputTopRight": vector(corners[1]),
            "inputBottomRight": vector(corners[2]),
            "inputBottomLeft": vector(corners[3]),
        ])
        return PixelFilter.render(warped, matching: buffer)
    }

    private func effectiveCorrections() -> (vertical: Double, horizontal: Double, rotate: Double) {
        guard upright == .guided, let first = guides.first else { return (vertical, horizontal, rotate) }
        let dx = first.endX - first.startX
        let dy = first.endY - first.startY
        let length = hypot(dx, dy)
        guard length > 1e-4 else { return (vertical, horizontal, rotate) }
        let angle = atan2(dy, dx) * 180 / .pi
        var guidedRotate = -angle
        if guidedRotate > 45 { guidedRotate -= 90 } else if guidedRotate < -45 { guidedRotate += 90 }
        return (vertical, horizontal, rotate + guidedRotate)
    }

    private func outputCorners(width: Int, height: Int, vertical: Double, horizontal: Double, rotation: Double) -> [CGPoint] {
        let w = Double(width)
        let h = Double(height)
        let v = vertical / 100 * w * 0.18
        let hz = horizontal / 100 * h * 0.18
        let aspectScale = 1 + aspect / 200
        let zoom = 1 + scale / 100
        let shiftX = offsetX / 100 * w * 0.15
        let shiftY = offsetY / 100 * h * 0.15
        var topLeft = CGPoint(x: -v + shiftX, y: h + shiftY)
        var topRight = CGPoint(x: w + v + shiftX, y: h + shiftY)
        var bottomRight = CGPoint(x: w + hz + shiftX, y: -shiftY)
        var bottomLeft = CGPoint(x: -hz + shiftX, y: -shiftY)
        let center = CGPoint(x: w / 2 + shiftX, y: h / 2 + shiftY)
        let radians = rotation * .pi / 180
        func rotated(_ point: CGPoint) -> CGPoint {
            let dx = point.x - center.x
            let dy = point.y - center.y
            let cosine = cos(radians)
            let sine = sin(radians)
            return CGPoint(x: center.x + dx * cosine - dy * sine, y: center.y + dx * sine + dy * cosine)
        }
        topLeft = rotated(topLeft)
        topRight = rotated(topRight)
        bottomRight = rotated(bottomRight)
        bottomLeft = rotated(bottomLeft)
        if aspectScale != 1 {
            func scaled(_ point: CGPoint) -> CGPoint {
                CGPoint(x: center.x + (point.x - center.x) * aspectScale, y: center.y + (point.y - center.y) / aspectScale)
            }
            topLeft = scaled(topLeft)
            topRight = scaled(topRight)
            bottomRight = scaled(bottomRight)
            bottomLeft = scaled(bottomLeft)
        }
        if zoom != 1 {
            func zoomed(_ point: CGPoint) -> CGPoint {
                CGPoint(x: center.x + (point.x - center.x) * zoom, y: center.y + (point.y - center.y) * zoom)
            }
            topLeft = zoomed(topLeft)
            topRight = zoomed(topRight)
            bottomRight = zoomed(bottomRight)
            bottomLeft = zoomed(bottomLeft)
        }
        return [topLeft, topRight, bottomRight, bottomLeft]
    }
}

struct CameraRawCalibrationSettings: Equatable, Sendable, Codable {
    var process: CameraRawProcessVersion = .version6
    var shadowTint: Double = 0
    var redHue: Double = 0
    var redSaturation: Double = 0
    var greenHue: Double = 0
    var greenSaturation: Double = 0
    var blueHue: Double = 0
    var blueSaturation: Double = 0

    var adjusts: Bool {
        shadowTint != 0 || redHue != 0 || redSaturation != 0 || greenHue != 0 || greenSaturation != 0 || blueHue != 0 || blueSaturation != 0
    }
}

struct CameraRawSettings: Equatable, Sendable, Codable {
    static let exposureRange: ClosedRange<Double> = -5...5
    static let toneRange: ClosedRange<Double> = -100...100
    static let temperatureGain = 0.35
    static let tintRedBlue = 0.15
    static let tintGreen = 0.30

    var whiteBalance: CameraRawWhiteBalance = .custom
    var temperature: Double = 0
    var tint: Double = 0
    var exposure: Double = 0
    var contrast: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var whites: Double = 0
    var blacks: Double = 0
    var vibrance: Double = 0
    var saturation: Double = 0
    var texture: Double = 0
    var clarity: Double = 0
    var dehaze: Double = 0
    var glow: Double = 0
    var glowStyle: CameraRawGlowStyle = .diffusion
    var glowRange: Double = 0
    var glowSpread: Double = 0
    var glowWarmth: Double = 0
    var vignetteAmount: Double = 0
    var vignetteStyle: CameraRawVignetteStyle = .highlightPriority
    var vignetteMidpoint: Double = 50
    var vignetteRoundness: Double = 0
    var vignetteFeather: Double = 50
    var vignetteHighlights: Double = 0
    var grainAmount: Double = 0
    var grainSize: Double = 25
    var grainRoughness: Double = 50
    var grainSeed: UInt32 = 0
    var curve = CameraRawCurveSettings()
    var mixer = CameraRawMixerSettings()
    var grading = CameraRawGradingSettings()
    var detail = CameraRawDetailSettings()
    var optics = CameraRawOpticsSettings()
    var geometry = CameraRawGeometrySettings()
    var calibration = CameraRawCalibrationSettings()

    var isIdentity: Bool {
        exposure == 0 && contrast == 0 && highlights == 0 && shadows == 0 && whites == 0 && blacks == 0
            && temperature == 0 && tint == 0 && vibrance == 0 && saturation == 0
            && texture == 0 && clarity == 0 && dehaze == 0 && glow == 0 && vignetteAmount == 0 && grainAmount == 0
            && !curve.adjusts && !mixer.adjusts && !grading.adjusts && !detail.adjusts && !optics.adjusts
            && !geometry.adjusts && !calibration.adjusts
    }

    var gains: (red: Double, green: Double, blue: Double) {
        let warm = temperature / 100
        let magenta = tint / 100
        return (
            1 + Self.temperatureGain * warm + Self.tintRedBlue * magenta,
            1 - Self.tintGreen * magenta,
            1 - Self.temperatureGain * warm + Self.tintRedBlue * magenta
        )
    }

    var grainKernelSize: Double { 0.5 + (grainSize / 100) * 19.5 }

    func apply(_ buffer: PixelBuffer) -> PixelBuffer {
        guard !isIdentity else { return buffer }
        return CameraRawPixels.apply(self, to: buffer)
    }

    static func neutralize(straightRed red: Double, green: Double, blue: Double) -> (temperature: Double, tint: Double)? {
        let linearRed = PixelMath.srgbToLinear(red)
        let linearGreen = PixelMath.srgbToLinear(green)
        let linearBlue = PixelMath.srgbToLinear(blue)
        guard linearRed > 1e-4, linearGreen > 1e-4, linearBlue > 1e-4 else { return nil }
        let a1 = temperatureGain * linearRed
        let b1 = tintRedBlue * linearRed + tintGreen * linearGreen
        let c1 = linearGreen - linearRed
        let a2 = -temperatureGain * linearBlue
        let b2 = tintRedBlue * linearBlue + tintGreen * linearGreen
        let c2 = linearGreen - linearBlue
        let determinant = a1 * b2 - a2 * b1
        guard abs(determinant) > 1e-8 else { return nil }
        let warm = (c1 * b2 - c2 * b1) / determinant
        let magenta = (a1 * c2 - a2 * c1) / determinant
        guard warm.isFinite, magenta.isFinite else { return nil }
        return (warm * 100, magenta * 100)
    }
}
