// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum GradientKind: String, CaseIterable, Identifiable, Sendable {
    case linear
    case radial

    var id: String { rawValue }
}

enum GradientFade: String, CaseIterable, Identifiable, Sendable {
    case toBackground
    case toTransparent

    var id: String { rawValue }
}

enum GradientRaster {
    static func paint(
        buffer: inout PixelBuffer,
        originX: Int,
        originY: Int,
        kind: GradientKind,
        start: CGPoint,
        end: CGPoint,
        from foreground: RGBA,
        to background: RGBA,
        opacity: CGFloat,
        coverage: [UInt8]?,
        canvasWidth: Int
    ) {
        let spanX = end.x - start.x
        let spanY = end.y - start.y
        let length2 = spanX * spanX + spanY * spanY
        guard length2 > 0.25 else { return }
        let length = length2.squareRoot()
        let opacityScale = min(max(opacity, 0), 1)
        guard opacityScale > 0 else { return }
        var bytes = buffer.copyBytes()
        let width = buffer.width
        let height = buffer.height
        for y in 0..<height {
            for x in 0..<width {
                let documentX = CGFloat(originX + x) + 0.5
                let documentY = CGFloat(originY + y) + 0.5
                var selection: CGFloat = 1
                if let coverage {
                    let canvasX = originX + x
                    let canvasY = originY + y
                    let canvasHeight = coverage.count / max(canvasWidth, 1)
                    guard canvasX >= 0, canvasY >= 0, canvasX < canvasWidth, canvasY < canvasHeight else { continue }
                    selection = CGFloat(coverage[canvasY * canvasWidth + canvasX]) / 255
                    if selection <= 0 { continue }
                }
                let t: CGFloat
                switch kind {
                case .linear:
                    t = min(1, max(0, ((documentX - start.x) * spanX + (documentY - start.y) * spanY) / length2))
                case .radial:
                    t = min(1, max(0, hypot(documentX - start.x, documentY - start.y) / length))
                }
                let color = mix(foreground, background, t: t)
                let amount = opacityScale * selection * (CGFloat(color.a) / 255)
                guard amount > 0 else { continue }
                let index = (y * width + x) * 4
                for channel in 0..<3 {
                    let source = CGFloat([color.r, color.g, color.b][channel])
                    let destination = CGFloat(bytes[index + channel])
                    bytes[index + channel] = UInt8(clamping: Int((destination + (source - destination) * amount).rounded()))
                }
                let destinationAlpha = CGFloat(bytes[index + 3])
                let sourceAlpha = CGFloat(color.a)
                bytes[index + 3] = UInt8(clamping: Int((destinationAlpha + (sourceAlpha - destinationAlpha) * opacityScale * selection).rounded()))
            }
        }
        buffer.setBytes(bytes)
    }

    private static func mix(_ start: RGBA, _ end: RGBA, t: CGFloat) -> RGBA {
        func channel(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(clamping: Int((CGFloat(a) + (CGFloat(b) - CGFloat(a)) * t).rounded()))
        }
        return RGBA(r: channel(start.r, end.r), g: channel(start.g, end.g), b: channel(start.b, end.b), a: channel(start.a, end.a))
    }
}
