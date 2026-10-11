// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

/// Patch-based content-aware fill, ported from Compositor's `content_fill`.
/// Selected pixels are synthesized from unselected opaque pixels. Transparent unselected
/// pixels are left alone and are not donors.
enum ContentFill {
    @discardableResult
    static func fill(buffer: inout PixelBuffer, coverage: [UInt8], canvasWidth: Int, originX: Int, originY: Int) -> Bool {
        guard canvasWidth > 0, coverage.count.isMultiple(of: canvasWidth) else { return false }
        let canvasHeight = coverage.count / canvasWidth
        var mask = [UInt8](repeating: 0, count: buffer.width * buffer.height)
        var missing = false
        for y in 0..<buffer.height {
            let canvasY = originY + y
            guard canvasY >= 0, canvasY < canvasHeight else { continue }
            for x in 0..<buffer.width {
                let canvasX = originX + x
                guard canvasX >= 0, canvasX < canvasWidth else { continue }
                if coverage[canvasY * canvasWidth + canvasX] > 0 {
                    mask[y * buffer.width + x] = 255
                    missing = true
                }
            }
        }
        guard missing else { return true }
        var bytes = buffer.copyBytes()
        guard fillBytes(&bytes, mask: mask, width: buffer.width, height: buffer.height) else { return false }
        buffer.setBytes(bytes)
        return true
    }

    static func fillBytes(_ pixels: inout [UInt8], mask: [UInt8], width: Int, height: Int) -> Bool {
        let count = width * height
        guard width > 0, height > 0, pixels.count == count * 4, mask.count == count else { return false }
        let stride = width * 4
        let radius = (width >= 5 && height >= 5) ? 2 : 0
        var known = [UInt8](repeating: 0, count: count)
        var target = [UInt8](repeating: 0, count: count)
        var valid = [UInt8](repeating: 0, count: count)
        var queued = [UInt8](repeating: 0, count: count)
        var donors: [Int] = []
        var chosen = [Int](repeating: -1, count: count)
        donors.reserveCapacity(count / 2)
        var missing = 0
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let selected = mask[index] != 0
                target[index] = selected ? 1 : 0
                let opaque = pixels[index * 4 + 3] == 255
                known[index] = !selected && opaque ? 1 : 0
                if selected { missing += 1 }
            }
        }
        if missing == 0 { return true }
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                guard known[index] != 0 else { continue }
                var ok = true
                for dy in -radius...radius where ok {
                    for dx in -radius...radius {
                        let sx = x + dx
                        let sy = y + dy
                        if sx < 0 || sy < 0 || sx >= width || sy >= height || known[sy * width + sx] == 0 {
                            ok = false
                            break
                        }
                    }
                }
                if ok {
                    valid[index] = 1
                    donors.append(index)
                }
            }
        }
        guard !donors.isEmpty else { return false }
        var queue: [Int] = []
        queue.reserveCapacity(missing)
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                guard target[index] != 0 else { continue }
                let touches = (x > 0 && known[index - 1] != 0)
                    || (x + 1 < width && known[index + 1] != 0)
                    || (y > 0 && known[index - width] != 0)
                    || (y + 1 < height && known[index + width] != 0)
                if touches {
                    queue.append(index)
                    queued[index] = 1
                }
            }
        }
        var random = LCG(state: 0x6d2b79f5)
        var head = 0
        var scan = 0
        while true {
            while head < queue.count {
                let index = queue[head]
                head += 1
                let x = index % width
                let y = index / width
                var best = -1
                var score = Double.greatestFiniteMagnitude
                let neighbors = [
                    x > 0 ? index - 1 : -1,
                    x + 1 < width ? index + 1 : -1,
                    y > 0 ? index - width : -1,
                    y + 1 < height ? index + width : -1
                ]
                for attempt in 0..<28 {
                    var candidate = -1
                    if attempt < 4 {
                        let neighbor = neighbors[attempt]
                        if neighbor >= 0 {
                            let source = chosen[neighbor] >= 0 ? chosen[neighbor] : neighbor
                            candidate = source + (index - neighbor)
                        }
                    } else {
                        candidate = donors[Int(random.next() % UInt32(donors.count))]
                    }
                    guard candidate >= 0, candidate < count, valid[candidate] != 0 else { continue }
                    let match = matchScore(pixels, stride: stride, known: known, width: width, height: height, target: index, source: candidate, radius: radius)
                    if best < 0 || match < score {
                        score = match
                        best = candidate
                    }
                }
                if best < 0 { best = donors[0] }
                var step = 64
                while step >= 1 {
                    let qx = best % width + Int(random.next() % UInt32(2 * step + 1)) - step
                    let qy = best / width + Int(random.next() % UInt32(2 * step + 1)) - step
                    if qx >= 0, qy >= 0, qx < width, qy < height, valid[qy * width + qx] != 0 {
                        let candidate = qy * width + qx
                        let match = matchScore(pixels, stride: stride, known: known, width: width, height: height, target: index, source: candidate, radius: radius)
                        if match < score {
                            score = match
                            best = candidate
                        }
                    }
                    step /= 2
                }
                let destination = y * stride + x * 4
                let source = (best / width) * stride + (best % width) * 4
                pixels[destination] = pixels[source]
                pixels[destination + 1] = pixels[source + 1]
                pixels[destination + 2] = pixels[source + 2]
                pixels[destination + 3] = pixels[source + 3]
                known[index] = 1
                chosen[index] = best
                for neighbor in neighbors where neighbor >= 0 && target[neighbor] != 0 && known[neighbor] == 0 && queued[neighbor] == 0 {
                    queued[neighbor] = 1
                    queue.append(neighbor)
                }
            }
            while scan < count && (target[scan] == 0 || known[scan] != 0) { scan += 1 }
            if scan >= count { break }
            queue.append(scan)
            queued[scan] = 1
        }
        return true
    }

    private static func matchScore(
        _ pixels: [UInt8],
        stride: Int,
        known: [UInt8],
        width: Int,
        height: Int,
        target: Int,
        source: Int,
        radius: Int
    ) -> Double {
        let px = target % width
        let py = target / width
        let qx = source % width
        let qy = source / width
        var sum = 0.0
        var samples = 0
        for dy in -radius...radius {
            for dx in -radius...radius {
                let x = px + dx
                let y = py + dy
                let sx = qx + dx
                let sy = qy + dy
                if x < 0 || y < 0 || x >= width || y >= height || sx < 0 || sy < 0 || sx >= width || sy >= height || known[y * width + x] == 0 {
                    continue
                }
                let a = y * stride + x * 4
                let b = sy * stride + sx * 4
                for channel in 0..<4 {
                    let delta = Int(pixels[a + channel]) - Int(pixels[b + channel])
                    sum += Double(delta * delta)
                }
                samples += 1
            }
        }
        return samples > 0 ? sum / Double(samples) : .greatestFiniteMagnitude
    }

    private struct LCG {
        var state: UInt32
        mutating func next() -> UInt32 {
            state = state &* 1_664_525 &+ 1_013_904_223
            return state
        }
    }
}
