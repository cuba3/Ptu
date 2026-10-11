// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

/// Spot healing, ported from Compositor's `spot_heal`.
/// `mode` 0 is content-aware, 1 creates texture, 2 is proximity match.
/// Channels are straight RGBA, so healed values are clamped to 0...255 rather than to alpha.
enum SpotHeal {
    private static let outside: UInt8 = 0
    private static let ring: UInt8 = 1
    private static let hole: UInt8 = 2

    @discardableResult
    static func heal(buffer: inout PixelBuffer, coverage: [UInt8], opacity: CGFloat, mode: Int, seed: UInt32 = 1) -> Bool {
        guard coverage.count == buffer.width * buffer.height else { return false }
        var bytes = buffer.copyBytes()
        let changed = healBytes(
            &bytes,
            coverage: coverage,
            width: buffer.width,
            height: buffer.height,
            opacity: Float(opacity),
            mode: mode,
            seed: seed
        )
        if changed { buffer.setBytes(bytes) }
        return changed
    }

    static func healBytes(
        _ rgba: inout [UInt8],
        coverage: [UInt8],
        width: Int,
        height: Int,
        opacity: Float,
        mode: Int,
        seed: UInt32
    ) -> Bool {
        guard width > 0, height > 0, rgba.count == width * height * 4, coverage.count == width * height else { return false }
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        for y in 0..<height {
            for x in 0..<width where coverage[y * width + x] != 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x + 1)
                maxY = max(maxY, y + 1)
            }
        }
        guard maxX > minX, maxY > minY else { return false }
        let boundsWidth = maxX - minX
        let boundsHeight = maxY - minY
        let size = max(boundsWidth, boundsHeight)
        var ringReach = size / 8
        if ringReach < 2 { ringReach = 2 }
        if ringReach > 16 { ringReach = 16 }
        let workX0 = max(0, minX - ringReach)
        let workY0 = max(0, minY - ringReach)
        let workX1 = min(width, maxX + ringReach)
        let workY1 = min(height, maxY + ringReach)
        let workWidth = workX1 - workX0
        let workHeight = workY1 - workY0
        let count = workWidth * workHeight
        guard workWidth > 0, workHeight > 0 else { return false }

        var role = [UInt8](repeating: outside, count: count)
        var near = [UInt8](repeating: 0, count: count)
        for y in 0..<workHeight {
            for x in 0..<workWidth {
                let coverageIndex = (workY0 + y) * width + (workX0 + x)
                if coverage[coverageIndex] != 0 { role[y * workWidth + x] = hole }
            }
        }
        var prefix = [Int](repeating: 0, count: max(workWidth, workHeight) + 1)
        for y in 0..<workHeight {
            prefix[0] = 0
            for x in 0..<workWidth { prefix[x + 1] = prefix[x] + (role[y * workWidth + x] == hole ? 1 : 0) }
            for x in 0..<workWidth {
                let lo = max(0, x - ringReach)
                let hi = min(workWidth, x + ringReach + 1)
                near[y * workWidth + x] = prefix[hi] - prefix[lo] > 0 ? 1 : 0
            }
        }
        for x in 0..<workWidth {
            prefix[0] = 0
            for y in 0..<workHeight { prefix[y + 1] = prefix[y] + Int(near[y * workWidth + x]) }
            for y in 0..<workHeight {
                let lo = max(0, y - ringReach)
                let hi = min(workHeight, y + ringReach + 1)
                if role[y * workWidth + x] == outside && prefix[hi] - prefix[lo] > 0 {
                    role[y * workWidth + x] = ring
                }
            }
        }
        let ringCount = role.reduce(0) { $0 + ($1 == ring ? 1 : 0) }
        guard ringCount > 0 else { return false }

        var sourceX = 0
        var sourceY = 0
        var haveSource = false
        if mode != 1 {
            let factors: [Double] = [1.05, 1.35, 1.75, 2.25, 2.8]
            let factorCount = mode == 2 ? 2 : 5
            var best = Double.infinity
            for factorIndex in 0..<factorCount {
                for angleIndex in 0..<24 {
                    let angle = Double(angleIndex) * Double.pi / 12
                    let dx = Int((cos(angle) * factors[factorIndex] * Double(workWidth)).rounded())
                    let dy = Int((sin(angle) * factors[factorIndex] * Double(workHeight)).rounded())
                    var score = patchScore(rgba, width: width, role: role, workX0: workX0, workY0: workY0, workWidth: workWidth, workHeight: workHeight, dx: dx, dy: dy, imageWidth: width, imageHeight: height)
                    guard score.isFinite else { continue }
                    score *= mode == 2 ? 1 + 0.6 * Double(factorIndex) : 1 + 0.1 * Double(factorIndex)
                    if score < best {
                        best = score
                        sourceX = dx
                        sourceY = dy
                    }
                }
            }
            if best.isFinite {
                let centerX = sourceX
                let centerY = sourceY
                var refined = patchScore(rgba, width: width, role: role, workX0: workX0, workY0: workY0, workWidth: workWidth, workHeight: workHeight, dx: centerX, dy: centerY, imageWidth: width, imageHeight: height)
                for j in -3...3 {
                    for i in -3...3 {
                        let score = patchScore(rgba, width: width, role: role, workX0: workX0, workY0: workY0, workWidth: workWidth, workHeight: workHeight, dx: centerX + i, dy: centerY + j, imageWidth: width, imageHeight: height)
                        if score < refined {
                            refined = score
                            sourceX = centerX + i
                            sourceY = centerY + j
                        }
                    }
                }
                haveSource = true
            }
        }

        var value = [Float](repeating: 0, count: count * 4)
        var mean = [Double](repeating: 0, count: 4)
        var detail = [Double](repeating: 0, count: 3)
        for y in 0..<workHeight {
            for x in 0..<workWidth {
                let index = y * workWidth + x
                guard role[index] == ring else { continue }
                let imageX = workX0 + x
                let imageY = workY0 + y
                let target = (imageY * width + imageX) * 4
                let sourceIndex = haveSource ? ((imageY + sourceY) * width + (imageX + sourceX)) * 4 : -1
                for channel in 0..<4 {
                    let sourceValue = sourceIndex >= 0 ? Float(rgba[sourceIndex + channel]) : 0
                    value[index * 4 + channel] = Float(rgba[target + channel]) - sourceValue
                    mean[channel] += Double(value[index * 4 + channel])
                }
                if !haveSource {
                    for channel in 0..<3 {
                        var around = 0.0
                        var neighbors = 0
                        for step in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                            let nx = imageX + step.0
                            let ny = imageY + step.1
                            guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                            around += Double(rgba[(ny * width + nx) * 4 + channel])
                            neighbors += 1
                        }
                        if neighbors > 0 {
                            let delta = Double(rgba[target + channel]) - around / Double(neighbors)
                            detail[channel] += delta * delta
                        }
                    }
                }
            }
        }
        for channel in 0..<4 { mean[channel] /= Double(ringCount) }
        for index in 0..<count where role[index] == hole {
            for channel in 0..<4 { value[index * 4 + channel] = Float(mean[channel]) }
        }
        solve(&value, role: role, width: workWidth, height: workHeight, depth: 0)
        for channel in 0..<3 { detail[channel] = (detail[channel] / Double(ringCount)).squareRoot() * 0.9 }

        var wrote = false
        for y in 0..<workHeight {
            for x in 0..<workWidth {
                let index = y * workWidth + x
                guard role[index] == hole else { continue }
                let imageX = workX0 + x
                let imageY = workY0 + y
                let target = (imageY * width + imageX) * 4
                let sourceIndex = haveSource ? ((imageY + sourceY) * width + (imageX + sourceX)) * 4 : -1
                let amount = Double(coverage[imageY * width + imageX]) / 255 * Double(opacity)
                var grain = 0.0
                if !haveSource {
                    let key = hash(seed ^ hash(UInt32(imageY * width + imageX)))
                    let u1 = unit(key)
                    let u2 = unit(key ^ 0x68e31da4)
                    grain = (-2 * log(1 - u1)).squareRoot() * cos(2 * Double.pi * u2)
                }
                for channel in 0..<4 {
                    let sourceValue = sourceIndex >= 0 ? Double(rgba[sourceIndex + channel]) : 0
                    let grainValue = channel < 3 ? grain * detail[channel] : 0
                    let healed = sourceValue + Double(value[index * 4 + channel]) + grainValue
                    let mixed = Double(rgba[target + channel]) + (healed - Double(rgba[target + channel])) * amount
                    rgba[target + channel] = UInt8(clamping: Int(min(255, max(0, mixed)).rounded()))
                }
                wrote = true
            }
        }
        return wrote
    }

    private static func patchScore(
        _ rgba: [UInt8],
        width: Int,
        role: [UInt8],
        workX0: Int,
        workY0: Int,
        workWidth: Int,
        workHeight: Int,
        dx: Int,
        dy: Int,
        imageWidth: Int,
        imageHeight: Int
    ) -> Double {
        if abs(dx) < workWidth && abs(dy) < workHeight { return .infinity }
        if workX0 + dx < 0 || workY0 + dy < 0 || workX0 + workWidth + dx > imageWidth || workY0 + workHeight + dy > imageHeight {
            return .infinity
        }
        var sum = 0.0
        var samples = 0
        for y in 0..<workHeight {
            for x in 0..<workWidth where role[y * workWidth + x] == ring {
                let target = ((workY0 + y) * width + (workX0 + x)) * 4
                let source = ((workY0 + y + dy) * width + (workX0 + x + dx)) * 4
                for channel in 0..<4 {
                    let delta = Double(rgba[target + channel]) - Double(rgba[source + channel])
                    sum += delta * delta
                }
                samples += 1
            }
        }
        return samples > 0 ? sum / Double(samples) : .infinity
    }

    private static func solve(_ value: inout [Float], role: [UInt8], width: Int, height: Int, depth: Int) {
        var iterations = 80
        if width > 32 && height > 32 && depth < 8 {
            let coarseWidth = (width + 1) / 2
            let coarseHeight = (height + 1) / 2
            var coarse = [Float](repeating: 0, count: coarseWidth * coarseHeight * 4)
            var coarseRole = [UInt8](repeating: outside, count: coarseWidth * coarseHeight)
            for y in 0..<coarseHeight {
                for x in 0..<coarseWidth {
                    var known = 0
                    var holes = 0
                    var knownSum = [Float](repeating: 0, count: 4)
                    var holeSum = [Float](repeating: 0, count: 4)
                    for j in 0..<2 {
                        for i in 0..<2 {
                            let fx = x * 2 + i
                            let fy = y * 2 + j
                            guard fx < width, fy < height else { continue }
                            let index = fy * width + fx
                            if role[index] == ring {
                                known += 1
                                for channel in 0..<4 { knownSum[channel] += value[index * 4 + channel] }
                            } else if role[index] == hole {
                                holes += 1
                                for channel in 0..<4 { holeSum[channel] += value[index * 4 + channel] }
                            }
                        }
                    }
                    let coarseIndex = y * coarseWidth + x
                    if known > 0 {
                        coarseRole[coarseIndex] = ring
                        for channel in 0..<4 { coarse[coarseIndex * 4 + channel] = knownSum[channel] / Float(known) }
                    } else if holes > 0 {
                        coarseRole[coarseIndex] = hole
                        for channel in 0..<4 { coarse[coarseIndex * 4 + channel] = holeSum[channel] / Float(holes) }
                    }
                }
            }
            solve(&coarse, role: coarseRole, width: coarseWidth, height: coarseHeight, depth: depth + 1)
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    let coarseIndex = (y / 2) * coarseWidth + x / 2
                    if role[index] == hole && coarseRole[coarseIndex] == hole {
                        for channel in 0..<4 { value[index * 4 + channel] = coarse[coarseIndex * 4 + channel] }
                    }
                }
            }
            iterations = 24
        }
        let omega: Float = 1.8
        for _ in 0..<iterations {
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    guard role[index] == hole else { continue }
                    var sum = [Float](repeating: 0, count: 4)
                    var neighbors = 0
                    for step in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                        let nx = x + step.0
                        let ny = y + step.1
                        guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                        let neighbor = ny * width + nx
                        guard role[neighbor] != outside else { continue }
                        for channel in 0..<4 { sum[channel] += value[neighbor * 4 + channel] }
                        neighbors += 1
                    }
                    guard neighbors > 0 else { continue }
                    for channel in 0..<4 {
                        value[index * 4 + channel] += omega * (sum[channel] / Float(neighbors) - value[index * 4 + channel])
                    }
                }
            }
        }
    }

    private static func hash(_ value: UInt32) -> UInt32 {
        var x = value
        x ^= x >> 16
        x &*= 0x7feb352d
        x ^= x >> 15
        x &*= 0x846ca68b
        x ^= x >> 16
        return x
    }

    private static func unit(_ key: UInt32) -> Double {
        Double(hash(key) >> 8) / 16_777_216
    }
}
