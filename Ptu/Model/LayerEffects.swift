// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

struct StrokeEffect: Codable, Equatable, Sendable {
    init() {}
    static let maxSize: CGFloat = 500
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var size: CGFloat = 4
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: Double = 1
    var inside = false

    var color: RGBA {
        RGBA(r: PixelMath.byte(red), g: PixelMath.byte(green), b: PixelMath.byte(blue), a: 255)
    }
}

struct ShadowEffect: Codable, Equatable, Sendable {
    init() {}
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var angle: CGFloat = 90
    var distance: CGFloat = 20
    var blur: CGFloat = 20
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: Double = 0.5

    var color: RGBA {
        RGBA(r: PixelMath.byte(red), g: PixelMath.byte(green), b: PixelMath.byte(blue), a: 255)
    }

    /// Shadow offset in layer pixels. Y grows downward.
    var offset: CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: -cos(radians) * distance, height: sin(radians) * distance)
    }
}

struct ColorOverlayEffect: Codable, Equatable, Sendable {
    init() {}
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: Double = 1

    var color: RGBA {
        RGBA(r: PixelMath.byte(red), g: PixelMath.byte(green), b: PixelMath.byte(blue), a: 255)
    }
}

struct InnerShadowEffect: Codable, Equatable, Sendable {
    init() {}
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var angle: CGFloat = 90
    var distance: CGFloat = 10
    var blur: CGFloat = 10
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: Double = 0.5

    var color: RGBA {
        RGBA(r: PixelMath.byte(red), g: PixelMath.byte(green), b: PixelMath.byte(blue), a: 255)
    }

    var offset: CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: -cos(radians) * distance, height: sin(radians) * distance)
    }
}

struct OuterGlowEffect: Codable, Equatable, Sendable {
    init() {}
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var size: CGFloat = 20
    var red: CGFloat = 1
    var green: CGFloat = 1
    var blue: CGFloat = 1
    var opacity: Double = 0.75

    var color: RGBA {
        RGBA(r: PixelMath.byte(red), g: PixelMath.byte(green), b: PixelMath.byte(blue), a: 255)
    }
}

struct InnerGlowEffect: Codable, Equatable, Sendable {
    init() {}
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var size: CGFloat = 10
    var red: CGFloat = 1
    var green: CGFloat = 1
    var blue: CGFloat = 1
    var opacity: Double = 0.75

    var color: RGBA {
        RGBA(r: PixelMath.byte(red), g: PixelMath.byte(green), b: PixelMath.byte(blue), a: 255)
    }
}

enum LayerEffectKind: String, CaseIterable, Sendable, Identifiable {
    case stroke
    case shadow
    case colorOverlay
    case innerShadow
    case outerGlow
    case innerGlow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stroke: L10n.Effect.stroke
        case .shadow: L10n.Effect.dropShadow
        case .colorOverlay: L10n.Effect.colorOverlay
        case .innerShadow: L10n.Effect.innerShadow
        case .outerGlow: L10n.Effect.outerGlow
        case .innerGlow: L10n.Effect.innerGlow
        }
    }
}

struct LayerEffects: Codable, Equatable, Sendable {
    init() {}

    var stroke: StrokeEffect?
    var shadow: ShadowEffect?
    var colorOverlay: ColorOverlayEffect?
    var innerShadow: InnerShadowEffect?
    var outerGlow: OuterGlowEffect?
    var innerGlow: InnerGlowEffect?

    var isEmpty: Bool {
        stroke == nil && shadow == nil && colorOverlay == nil && innerShadow == nil && outerGlow == nil && innerGlow == nil
    }

    func contains(_ kind: LayerEffectKind) -> Bool {
        switch kind {
        case .stroke: stroke != nil
        case .shadow: shadow != nil
        case .colorOverlay: colorOverlay != nil
        case .innerShadow: innerShadow != nil
        case .outerGlow: outerGlow != nil
        case .innerGlow: innerGlow != nil
        }
    }

    func isEnabled(_ kind: LayerEffectKind) -> Bool {
        switch kind {
        case .stroke: stroke?.isEnabled == true
        case .shadow: shadow?.isEnabled == true
        case .colorOverlay: colorOverlay?.isEnabled == true
        case .innerShadow: innerShadow?.isEnabled == true
        case .outerGlow: outerGlow?.isEnabled == true
        case .innerGlow: innerGlow?.isEnabled == true
        }
    }

    mutating func setEnabled(_ enabled: Bool, for kind: LayerEffectKind) {
        switch kind {
        case .stroke: stroke?.enabled = enabled
        case .shadow: shadow?.enabled = enabled
        case .colorOverlay: colorOverlay?.enabled = enabled
        case .innerShadow: innerShadow?.enabled = enabled
        case .outerGlow: outerGlow?.enabled = enabled
        case .innerGlow: innerGlow?.enabled = enabled
        }
    }

    mutating func ensure(_ kind: LayerEffectKind, color: RGBA) {
        switch kind {
        case .stroke where stroke == nil:
            var effect = StrokeEffect()
            effect.red = PixelMath.unit(color.r)
            effect.green = PixelMath.unit(color.g)
            effect.blue = PixelMath.unit(color.b)
            stroke = effect
        case .shadow where shadow == nil:
            shadow = ShadowEffect()
        case .colorOverlay where colorOverlay == nil:
            var effect = ColorOverlayEffect()
            effect.red = PixelMath.unit(color.r)
            effect.green = PixelMath.unit(color.g)
            effect.blue = PixelMath.unit(color.b)
            colorOverlay = effect
        case .innerShadow where innerShadow == nil:
            innerShadow = InnerShadowEffect()
        case .outerGlow where outerGlow == nil:
            outerGlow = OuterGlowEffect()
        case .innerGlow where innerGlow == nil:
            innerGlow = InnerGlowEffect()
        default:
            break
        }
    }

    var visible: LayerEffects {
        var shown = LayerEffects()
        if stroke?.isEnabled == true { shown.stroke = stroke }
        if shadow?.isEnabled == true { shown.shadow = shadow }
        if colorOverlay?.isEnabled == true { shown.colorOverlay = colorOverlay }
        if innerShadow?.isEnabled == true { shown.innerShadow = innerShadow }
        if outerGlow?.isEnabled == true { shown.outerGlow = outerGlow }
        if innerGlow?.isEnabled == true { shown.innerGlow = innerGlow }
        return shown
    }

    var margin: Int {
        let effects = visible
        var margin: CGFloat = 0
        if let stroke = effects.stroke, !stroke.inside { margin = max(margin, stroke.size) }
        if let shadow = effects.shadow { margin = max(margin, shadow.distance + shadow.blur * 3) }
        if let glow = effects.outerGlow { margin = max(margin, glow.size * 3) }
        if margin <= 0 { return 0 }
        return Int(ceil(margin)) + 2
    }
}

enum LayerEffectsRenderer {
    static func render(_ source: PixelBuffer, effects: LayerEffects) -> (buffer: PixelBuffer, inset: Int) {
        let effects = effects.visible
        guard !effects.isEmpty else { return (source, 0) }
        let inset = effects.margin
        let width = source.width + inset * 2
        let height = source.height + inset * 2
        guard width <= DocumentModel.maximumSide, height <= DocumentModel.maximumSide else { return (source, 0) }
        var canvas = PixelBuffer(width: width, height: height, fill: .clear)
        let shape = coverage(of: source, inset: inset, width: width, height: height)
        if let shadow = effects.shadow, shadow.opacity > 0 {
            let moved = translated(shape, width: width, height: height, offset: shadow.offset)
            let soft = blurred(moved, width: width, height: height, radius: shadow.blur)
            paint(shadow.color, opacity: shadow.opacity, coverage: soft, into: &canvas)
        }
        if let glow = effects.outerGlow, glow.opacity > 0 {
            let soft = blurred(shape, width: width, height: height, radius: glow.size)
            var outside = soft
            for index in outside.indices {
                outside[index] = max(0, min(1, soft[index] * (1 - shape[index])))
            }
            paint(glow.color, opacity: glow.opacity, coverage: outside, into: &canvas)
        }
        if let stroke = effects.stroke, !stroke.inside, stroke.size > 0, stroke.opacity > 0 {
            paint(stroke.color, opacity: stroke.opacity, coverage: strokeRing(shape, width: width, height: height, stroke: stroke), into: &canvas)
        }
        var styled = PixelBuffer(width: width, height: height, fill: .clear)
        blit(source, into: &styled, atX: inset, y: inset)
        if let overlay = effects.colorOverlay, overlay.opacity > 0 {
            recolor(&styled, color: overlay.color, opacity: overlay.opacity, amount: nil)
        }
        if let glow = effects.innerGlow, glow.opacity > 0 {
            let soft = blurred(shape, width: width, height: height, radius: glow.size)
            let inside = soft.map { max(0, min(1, 1 - $0)) }
            recolor(&styled, color: glow.color, opacity: glow.opacity, amount: inside)
        }
        if let inner = effects.innerShadow, inner.opacity > 0 {
            let moved = translated(shape, width: width, height: height, offset: inner.offset)
            let soft = blurred(moved, width: width, height: height, radius: inner.blur)
            let inside = soft.map { max(0, min(1, 1 - $0)) }
            recolor(&styled, color: inner.color, opacity: inner.opacity, amount: inside)
        }
        sourceOver(styled, onto: &canvas)
        if let stroke = effects.stroke, stroke.inside, stroke.size > 0, stroke.opacity > 0 {
            paint(stroke.color, opacity: stroke.opacity, coverage: strokeRing(shape, width: width, height: height, stroke: stroke), into: &canvas)
        }
        return (canvas, inset)
    }

    private static func coverage(of source: PixelBuffer, inset: Int, width: Int, height: Int) -> [Float] {
        var plane = [Float](repeating: 0, count: width * height)
        for y in 0..<source.height {
            for x in 0..<source.width {
                plane[(y + inset) * width + (x + inset)] = Float(source.pixel(x: x, y: y).a) / 255
            }
        }
        return plane
    }

    private static func translated(_ source: [Float], width: Int, height: Int, offset: CGSize) -> [Float] {
        let dx = Int(offset.width.rounded())
        let dy = Int(offset.height.rounded())
        var plane = [Float](repeating: 0, count: source.count)
        for y in 0..<height {
            for x in 0..<width {
                let sx = x - dx
                let sy = y - dy
                guard sx >= 0, sy >= 0, sx < width, sy < height else { continue }
                plane[y * width + x] = source[sy * width + sx]
            }
        }
        return plane
    }

    private static func blurred(_ source: [Float], width: Int, height: Int, radius: CGFloat) -> [Float] {
        guard radius > 0 else { return source }
        let box = max(1, Int((radius / 2).rounded()))
        return PixelMath.boxBlur(source, width: width, height: height, radius: box)
    }

    private static func strokeRing(_ shape: [Float], width: Int, height: Int, stroke: StrokeEffect) -> [Float] {
        let reach = max(1, Int(stroke.size.rounded()))
        let grown = extreme(shape, width: width, height: height, reach: reach, smallest: stroke.inside)
        return zip(shape, grown).map { sample, moved in
            stroke.inside ? max(0, sample - moved) : max(0, moved - sample)
        }
    }

    /// Largest or smallest value inside a square window, via two sliding-window passes.
    static func extreme(_ source: [Float], width: Int, height: Int, reach: Int, smallest: Bool) -> [Float] {
        guard width > 0, height > 0, source.count == width * height else { return [] }
        let radius = max(0, reach)
        var pass = [Float](repeating: 0, count: source.count)
        var result = [Float](repeating: 0, count: source.count)
        func sweep(input: [Float], output: inout [Float], lines: Int, count: Int, lineStep: Int, elementStep: Int) {
            var queue = [Int](repeating: 0, count: max(width, height))
            for line in 0..<lines {
                let base = line * lineStep
                var head = 0
                var tail = 0
                var next = 0
                for center in 0..<count {
                    while next <= min(count - 1, center + radius) {
                        let value = input[base + next * elementStep]
                        while tail > head {
                            let previous = input[base + queue[tail - 1] * elementStep]
                            if smallest ? previous < value : previous > value { break }
                            tail -= 1
                        }
                        queue[tail] = next
                        tail += 1
                        next += 1
                    }
                    while head < tail, queue[head] < center - radius { head += 1 }
                    let outside = center < radius || center + radius >= count
                    output[base + center * elementStep] = smallest && outside ? 0 : input[base + queue[head] * elementStep]
                }
            }
        }
        sweep(input: source, output: &pass, lines: height, count: width, lineStep: width, elementStep: 1)
        sweep(input: pass, output: &result, lines: width, count: height, lineStep: 1, elementStep: width)
        return result
    }

    private static func paint(_ color: RGBA, opacity: Double, coverage: [Float], into buffer: inout PixelBuffer) {
        let width = buffer.width
        buffer.updateEach { x, y, pixel in
            let amount = Double(coverage[y * width + x]) * opacity
            guard amount > 0 else { return }
            pixel = sourceOver(source: color, sourceAlpha: amount, destination: pixel)
        }
    }

    private static func recolor(_ buffer: inout PixelBuffer, color: RGBA, opacity: Double, amount: [Float]?) {
        let width = buffer.width
        buffer.updateEach { x, y, pixel in
            guard pixel.a > 0 else { return }
            let coverage = amount.map { Double($0[y * width + x]) } ?? 1
            let mix = opacity * coverage
            guard mix > 0 else { return }
            pixel.r = PixelMath.byte(PixelMath.unit(pixel.r) * (1 - mix) + PixelMath.unit(color.r) * mix)
            pixel.g = PixelMath.byte(PixelMath.unit(pixel.g) * (1 - mix) + PixelMath.unit(color.g) * mix)
            pixel.b = PixelMath.byte(PixelMath.unit(pixel.b) * (1 - mix) + PixelMath.unit(color.b) * mix)
        }
    }

    private static func blit(_ source: PixelBuffer, into destination: inout PixelBuffer, atX originX: Int, y originY: Int) {
        for y in 0..<source.height {
            for x in 0..<source.width {
                destination.setPixel(x: x + originX, y: y + originY, rgba: source.pixel(x: x, y: y))
            }
        }
    }

    private static func sourceOver(_ source: PixelBuffer, onto destination: inout PixelBuffer) {
        destination.updateEach { x, y, pixel in
            let incoming = source.pixel(x: x, y: y)
            guard incoming.a > 0 else { return }
            pixel = sourceOver(source: incoming, sourceAlpha: PixelMath.unit(incoming.a), destination: pixel)
        }
    }

    private static func sourceOver(source: RGBA, sourceAlpha: Double, destination: RGBA) -> RGBA {
        let srcA = min(1, max(0, sourceAlpha))
        let dstA = PixelMath.unit(destination.a)
        let outA = srcA + dstA * (1 - srcA)
        guard outA > 0 else { return .clear }
        let srcR = PixelMath.unit(source.r)
        let srcG = PixelMath.unit(source.g)
        let srcB = PixelMath.unit(source.b)
        let dstR = PixelMath.unit(destination.r)
        let dstG = PixelMath.unit(destination.g)
        let dstB = PixelMath.unit(destination.b)
        return RGBA(
            r: PixelMath.byte((srcR * srcA + dstR * dstA * (1 - srcA)) / outA),
            g: PixelMath.byte((srcG * srcA + dstG * dstA * (1 - srcA)) / outA),
            b: PixelMath.byte((srcB * srcA + dstB * dstA * (1 - srcA)) / outA),
            a: PixelMath.byte(outA)
        )
    }
}
