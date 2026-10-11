// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

extension ToolsViewModel {
    func beginClone(at point: CGPoint, option: Bool) {
        if option {
            cloneSourcePoint = point
            storedCloneOffset = nil
            cloneStrokeOffset = nil
            toolMessage = nil
            overlayRevision &+= 1
            return
        }
        guard cloneSourcePoint != nil, let id = document.selectedLayerID, document.model.pixelLayer(id: id) != nil else {
            toolMessage = L10n.Clone.sourceHint
            return
        }
        toolMessage = nil
        if cloneAligned {
            if storedCloneOffset == nil, let source = cloneSourcePoint {
                storedCloneOffset = CGSize(width: (source.x - point.x).rounded(), height: (source.y - point.y).rounded())
            }
            cloneStrokeOffset = storedCloneOffset
        } else if let source = cloneSourcePoint {
            cloneStrokeOffset = CGSize(width: (source.x - point.x).rounded(), height: (source.y - point.y).rounded())
        }
        if sampleAllLayers, let composite = CanvasSample.composite(document.model) {
            cloneSnapshot = composite
            cloneSnapshotOrigin = .zero
        } else if let layer = document.model.pixelLayer(id: id) {
            cloneSnapshot = layer.buffer
            cloneSnapshotOrigin = CGPoint(x: layer.originX, y: layer.originY)
        }
        document.beginCoalescedEdit()
        lastBrushPoint = point
        paintClone([point])
    }

    func dragClone(to point: CGPoint) {
        guard lastBrushPoint != nil else { return }
        let points = spaced(from: lastBrushPoint ?? point, to: point)
        lastBrushPoint = point
        paintClone(points)
    }

    func finishClone(at point: CGPoint) {
        guard lastBrushPoint != nil else { return }
        dragClone(to: point)
        document.commitPainting()
        document.endCoalescedEdit()
        lastBrushPoint = nil
        cloneSnapshot = nil
        if !cloneAligned { cloneStrokeOffset = nil }
    }

    func cloneSamplePoint(for point: CGPoint) -> CGPoint? {
        guard let source = cloneSourcePoint else { return nil }
        if let offset = storedCloneOffset, cloneAligned {
            return CGPoint(x: point.x + offset.width, y: point.y + offset.height)
        }
        return source
    }

    private func paintClone(_ points: [CGPoint]) {
        guard let id = document.selectedLayerID,
              let layer = document.canvasModel().pixelLayer(id: id),
              let source = cloneSnapshot,
              let offset = cloneStrokeOffset else { return }
        let radius = CGFloat(brushSize) / 2
        let hardness = CGFloat(brushHardness)
        let opacity = CGFloat(brushOpacity)
        let origin = CGPoint(x: layer.originX, y: layer.originY)
        var dirty = CGRect.null
        document.withPaintingModel { live in
            guard var painted = live.pixelLayer(id: id) else { return }
            for point in points {
                let rect = CloneStamp.dab(
                    destination: &painted.buffer,
                    destinationOrigin: origin,
                    source: source,
                    sourceOrigin: cloneSnapshotOrigin,
                    center: point,
                    offset: offset,
                    radius: radius,
                    hardness: hardness,
                    opacity: opacity
                )
                if !rect.isNull { dirty = dirty.isNull ? rect : dirty.union(rect) }
            }
            live.replacePixelBuffer(id: id, buffer: painted.buffer)
        }
        guard !dirty.isNull else { return }
        document.notePaintDirty(dirty.insetBy(dx: -2, dy: -2))
    }

    func beginHeal(at point: CGPoint) {
        guard document.selectedLayerID != nil else { return }
        healDabs = [point]
        lastBrushPoint = point
        overlayRevision &+= 1
    }

    func dragHeal(to point: CGPoint) {
        guard lastBrushPoint != nil else { return }
        let points = spaced(from: lastBrushPoint ?? point, to: point)
        lastBrushPoint = point
        healDabs.append(contentsOf: points)
        overlayRevision &+= 1
    }

    func finishHeal(at point: CGPoint) {
        guard lastBrushPoint != nil else { return }
        dragHeal(to: point)
        let dabs = healDabs
        healDabs = []
        lastBrushPoint = nil
        guard let id = document.selectedLayerID, var layer = document.model.pixelLayer(id: id) else { return }
        var coverage = [UInt8](repeating: 0, count: layer.buffer.width * layer.buffer.height)
        let radius = CGFloat(brushSize) / 2
        let hardness = CGFloat(brushHardness)
        for dab in dabs {
            let center = CGPoint(x: dab.x - CGFloat(layer.originX), y: dab.y - CGFloat(layer.originY))
            stampCoverage(&coverage, width: layer.buffer.width, height: layer.buffer.height, center: center, radius: radius, hardness: hardness)
        }
        guard coverage.contains(where: { $0 > 0 }) else { return }
        let mode = healMode
        let opacity = CGFloat(brushOpacity)
        document.edit(redraw: .full) { model in
            guard var painted = model.pixelLayer(id: id) else { return }
            _ = SpotHeal.heal(buffer: &painted.buffer, coverage: coverage, opacity: opacity, mode: mode)
            model.replacePixelBuffer(id: id, buffer: painted.buffer)
        }
        layer = document.model.pixelLayer(id: id) ?? layer
    }

    func beginBlur(at point: CGPoint) {
        guard let id = document.selectedLayerID, let layer = document.model.pixelLayer(id: id) else { return }
        let sigma = min(40, max(0.5, blurRadius))
        blurredSample = SmudgeBlur.gaussian(layer.buffer, sigma: sigma)
        document.beginCoalescedEdit()
        lastBrushPoint = point
        paintBlur([point])
    }

    func dragBlur(to point: CGPoint) {
        guard lastBrushPoint != nil else { return }
        let points = spaced(from: lastBrushPoint ?? point, to: point, spacing: max(1, CGFloat(brushSize) * 0.2))
        lastBrushPoint = point
        paintBlur(points)
    }

    func finishBlur(at point: CGPoint) {
        guard lastBrushPoint != nil else { return }
        dragBlur(to: point)
        document.commitPainting()
        document.endCoalescedEdit()
        lastBrushPoint = nil
        blurredSample = nil
    }

    private func paintBlur(_ points: [CGPoint]) {
        guard let id = document.selectedLayerID,
              let layer = document.canvasModel().pixelLayer(id: id),
              let blurred = blurredSample else { return }
        let radius = CGFloat(brushSize) / 2
        let hardness = CGFloat(brushHardness)
        let opacity = CGFloat(brushOpacity)
        var dirty = CGRect.null
        document.withPaintingModel { live in
            guard var painted = live.pixelLayer(id: id) else { return }
            for point in points {
                let local = CGPoint(x: point.x - CGFloat(layer.originX), y: point.y - CGFloat(layer.originY))
                let rect = mixDab(destination: &painted.buffer, source: blurred, center: local, radius: radius, hardness: hardness, opacity: opacity)
                if !rect.isNull {
                    let documentRect = rect.offsetBy(dx: CGFloat(layer.originX), dy: CGFloat(layer.originY))
                    dirty = dirty.isNull ? documentRect : dirty.union(documentRect)
                }
            }
            live.replacePixelBuffer(id: id, buffer: painted.buffer)
        }
        guard !dirty.isNull else { return }
        document.notePaintDirty(dirty.insetBy(dx: -2, dy: -2))
    }

    func beginSmudge(at point: CGPoint) {
        guard let id = document.selectedLayerID, let layer = document.model.pixelLayer(id: id) else { return }
        let local = CGPoint(x: point.x - CGFloat(layer.originX), y: point.y - CGFloat(layer.originY))
        if smudgeMode == .smudge {
            smudgeCarried = SmudgeBlur.pickUp(buffer: layer.buffer, center: local, radius: Int((CGFloat(brushSize) / 2).rounded(.up)))
        }
        document.beginCoalescedEdit()
        lastBrushPoint = point
    }

    func dragSmudge(to point: CGPoint) {
        guard let last = lastBrushPoint else { return }
        let spacing: CGFloat = smudgeMode == .smudge ? max(1, CGFloat(brushSize) * 0.08) : max(1, CGFloat(brushSize) * 0.05)
        let points = spaced(from: last, to: point, spacing: spacing)
        guard !points.isEmpty else { return }
        lastBrushPoint = point
        guard let id = document.selectedLayerID, let layer = document.canvasModel().pixelLayer(id: id) else { return }
        let diameter = CGFloat(brushSize)
        let hardness = CGFloat(brushHardness)
        let strength = CGFloat(brushOpacity)
        let origin = CGPoint(x: layer.originX, y: layer.originY)
        var dirty = CGRect.null
        var previous = last
        document.withPaintingModel { live in
            guard var painted = live.pixelLayer(id: id) else { return }
            var carried = smudgeCarried
            for next in points {
                let from = CGPoint(x: previous.x - origin.x, y: previous.y - origin.y)
                let to = CGPoint(x: next.x - origin.x, y: next.y - origin.y)
                if smudgeMode == .smudge {
                    SmudgeBlur.smudge(buffer: &painted.buffer, carried: &carried, center: to, diameter: diameter, hardness: hardness, strength: strength)
                } else {
                    SmudgeBlur.push(buffer: &painted.buffer, from: from, to: to, diameter: diameter, hardness: hardness, strength: strength)
                }
                let rect = CGRect(x: next.x - diameter, y: next.y - diameter, width: diameter * 2, height: diameter * 2)
                dirty = dirty.isNull ? rect : dirty.union(rect)
                previous = next
            }
            smudgeCarried = carried
            live.replacePixelBuffer(id: id, buffer: painted.buffer)
        }
        guard !dirty.isNull else { return }
        document.notePaintDirty(dirty.insetBy(dx: -2, dy: -2))
    }

    func finishSmudge(at point: CGPoint) {
        guard lastBrushPoint != nil else { return }
        dragSmudge(to: point)
        document.commitPainting()
        document.endCoalescedEdit()
        lastBrushPoint = nil
        smudgeCarried = []
    }

    func spaced(from last: CGPoint, to point: CGPoint, spacing: CGFloat? = nil) -> [CGPoint] {
        let radius = CGFloat(brushSize) / 2
        let step = spacing ?? max(1, radius * 0.25)
        let distance = hypot(point.x - last.x, point.y - last.y)
        let count = max(1, Int((distance / step).rounded(.up)))
        var points: [CGPoint] = []
        points.reserveCapacity(count)
        for index in 1...count {
            let t = CGFloat(index) / CGFloat(count)
            points.append(CGPoint(x: last.x + (point.x - last.x) * t, y: last.y + (point.y - last.y) * t))
        }
        return points
    }

    private func stampCoverage(_ coverage: inout [UInt8], width: Int, height: Int, center: CGPoint, radius: CGFloat, hardness: CGFloat) {
        let minX = max(0, Int(floor(center.x - radius)))
        let maxX = min(width - 1, Int(ceil(center.x + radius)))
        let minY = max(0, Int(floor(center.y - radius)))
        let maxY = min(height - 1, Int(ceil(center.y + radius)))
        guard minX <= maxX, minY <= maxY else { return }
        for y in minY...maxY {
            for x in minX...maxX {
                let falloff = BrushCoverage.weight(
                    dx: CGFloat(x) + 0.5 - center.x,
                    dy: CGFloat(y) + 0.5 - center.y,
                    radius: radius,
                    hardness: hardness
                )
                guard falloff > 0 else { continue }
                let index = y * width + x
                let value = UInt8(clamping: Int((falloff * 255).rounded()))
                if value > coverage[index] { coverage[index] = value }
            }
        }
    }

    private func mixDab(destination: inout PixelBuffer, source: PixelBuffer, center: CGPoint, radius: CGFloat, hardness: CGFloat, opacity: CGFloat) -> CGRect {
        let minX = max(0, Int(floor(center.x - radius)))
        let maxX = min(destination.width - 1, Int(ceil(center.x + radius)))
        let minY = max(0, Int(floor(center.y - radius)))
        let maxY = min(destination.height - 1, Int(ceil(center.y + radius)))
        guard minX <= maxX, minY <= maxY else { return .null }
        for y in minY...maxY {
            for x in minX...maxX {
                let falloff = BrushCoverage.weight(
                    dx: CGFloat(x) + 0.5 - center.x,
                    dy: CGFloat(y) + 0.5 - center.y,
                    radius: radius,
                    hardness: hardness
                )
                guard falloff > 0 else { continue }
                destination.mixPixel(x: x, y: y, color: source.pixel(x: x, y: y), amount: opacity * falloff)
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
