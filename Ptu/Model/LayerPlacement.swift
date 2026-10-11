// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

enum LayerSampling: String, CaseIterable, Sendable, Identifiable {
    case nearest
    case smooth
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nearest: L10n.Sampling.nearest
        case .smooth: L10n.Sampling.smooth
        case .high: L10n.Sampling.high
        }
    }

    var quality: CGInterpolationQuality {
        switch self {
        case .nearest: .none
        case .smooth: .low
        case .high: .high
        }
    }
}

/// Unrotated box in document pixels. Rotation is clockwise around the center, y down.
struct LayerPlacement: Equatable, Sendable {
    var origin: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var flipX = false
    var flipY = false
    var sampling: LayerSampling = .smooth

    var center: CGPoint { CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2) }
    var radians: CGFloat { rotation.truncatingRemainder(dividingBy: 360) * .pi / 180 }

    var isValid: Bool {
        [origin.x, origin.y, size.width, size.height, rotation].allSatisfy(\.isFinite)
            && (1...CGFloat(DocumentModel.maximumSide)).contains(size.width)
            && (1...CGFloat(DocumentModel.maximumSide)).contains(size.height)
            && abs(origin.x) <= 1_000_000 && abs(origin.y) <= 1_000_000
    }

    static let handles = [
        CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0),
        CGPoint(x: 1, y: 0.5), CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 1),
        CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 0.5),
    ]

    func point(_ unit: CGPoint) -> CGPoint {
        let x = (unit.x - 0.5) * size.width
        let y = (unit.y - 0.5) * size.height
        return CGPoint(
            x: center.x + x * cos(radians) - y * sin(radians),
            y: center.y + x * sin(radians) + y * cos(radians)
        )
    }

    func contains(_ point: CGPoint) -> Bool {
        let x = point.x - center.x
        let y = point.y - center.y
        return abs(x * cos(radians) + y * sin(radians)) <= size.width / 2
            && abs(-x * sin(radians) + y * cos(radians)) <= size.height / 2
    }

    func corners() -> [CGPoint] {
        [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)].map(point)
    }
}

enum PlacementDrag {
    enum Mode: Equatable {
        case move
        case resize(Int)
        case rotate
    }

    static func updated(
        original: LayerPlacement,
        mode: Mode,
        start: CGPoint,
        point: CGPoint,
        lockRatio: Bool,
        shift: Bool,
        option: Bool
    ) -> LayerPlacement {
        var result = original
        switch mode {
        case .move:
            var dx = point.x - start.x
            var dy = point.y - start.y
            if shift {
                if abs(dx) >= abs(dy) { dy = 0 } else { dx = 0 }
            }
            result.origin.x += dx
            result.origin.y += dy
        case .rotate:
            let center = original.center
            let delta = atan2(point.y - center.y, point.x - center.x) - atan2(start.y - center.y, start.x - center.x)
            result.rotation += delta * 180 / .pi
            if shift { result.rotation = (result.rotation / 15).rounded() * 15 }
        case .resize(let index):
            let handle = LayerPlacement.handles[index]
            let anchorUnit = option ? CGPoint(x: 0.5, y: 0.5) : CGPoint(x: 1 - handle.x, y: 1 - handle.y)
            let anchor = original.point(anchorUnit)
            let initialHandle = original.point(handle)
            let dx = initialHandle.x + point.x - start.x - anchor.x
            let dy = initialHandle.y + point.y - start.y - anchor.y
            let span: CGFloat = option ? 2 : 1
            let localX = (dx * cos(original.radians) + dy * sin(original.radians)) * span
            let localY = (-dx * sin(original.radians) + dy * cos(original.radians)) * span
            let sx = handle.x * 2 - 1
            let sy = handle.y * 2 - 1
            let rawWidth = sx == 0 ? original.size.width : localX * sx
            let rawHeight = sy == 0 ? original.size.height : localY * sy
            let mirroredX = rawWidth < 0
            let mirroredY = rawHeight < 0
            var width = max(1, abs(rawWidth))
            var height = max(1, abs(rawHeight))
            if lockRatio != shift {
                let factor: CGFloat
                if sx == 0 {
                    factor = height / original.size.height
                } else if sy == 0 {
                    factor = width / original.size.width
                } else {
                    factor = max(
                        1 / min(original.size.width, original.size.height),
                        (localX * sx * original.size.width + localY * sy * original.size.height)
                            / (original.size.width * original.size.width + original.size.height * original.size.height)
                    )
                }
                width = original.size.width * factor
                height = original.size.height * factor
            }
            result.size = CGSize(width: width, height: height)
            if mirroredX { result.flipX.toggle() }
            if mirroredY { result.flipY.toggle() }
            let offsetX = (0.5 - anchorUnit.x) * width * (mirroredX ? -1 : 1)
            let offsetY = (0.5 - anchorUnit.y) * height * (mirroredY ? -1 : 1)
            let center = CGPoint(
                x: anchor.x + offsetX * cos(original.radians) - offsetY * sin(original.radians),
                y: anchor.y + offsetX * sin(original.radians) + offsetY * cos(original.radians)
            )
            result.origin = CGPoint(x: center.x - width / 2, y: center.y - height / 2)
        }
        return result.isValid ? result : original
    }

    /// Corner indices moved by a distort drag. Handle order matches `LayerPlacement.handles`.
    static func movedCorners(handle: Int) -> [Int] {
        if handle.isMultiple(of: 2) {
            return [handle / 2]
        }
        return [handle / 2, (handle / 2 + 1) % 4]
    }

    static func draggedCorners(_ corners: [CGPoint], indices: [Int], from start: CGPoint, to point: CGPoint, shift: Bool) -> [CGPoint] {
        var result = corners
        var dx = point.x - start.x
        var dy = point.y - start.y
        if shift {
            if abs(dx) >= abs(dy) { dy = 0 } else { dx = 0 }
        }
        for index in indices where result.indices.contains(index) {
            result[index].x += dx
            result[index].y += dy
        }
        return result
    }
}
