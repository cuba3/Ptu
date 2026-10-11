// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import ImageIO
import Observation
import SwiftUI

@MainActor
@Observable
final class JPEGExportViewModel {
    static let qualityKey = "ptu.jpegExportQuality"
    var quality: Double
    var byteCount: Int?
    var preview: CGImage?
    var failed = false
    private var source: CGImage?
    private var ppi: Double = 72

    init() {
        let saved = UserDefaults.standard.object(forKey: Self.qualityKey) as? Double
        let starting = saved ?? 0.9
        quality = min(1, max(0.01, starting))
    }

    func configure(image: CGImage, ppi: Double) {
        source = Self.mattedOnWhite(image)
        self.ppi = ppi
        preview = nil
        byteCount = nil
        failed = false
    }

    func encode() {
        guard let source else {
            failed = true
            return
        }
        do {
            let data = try ImageFiles.jpegData(from: source, ppi: ppi, quality: quality)
            byteCount = data.count
            if let provider = CGImageSourceCreateWithData(data as CFData, nil) {
                preview = CGImageSourceCreateImageAtIndex(provider, 0, nil)
            }
            failed = preview == nil
        } catch {
            failed = true
            preview = nil
            byteCount = nil
        }
    }

    private static func mattedOnWhite(_ image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return image }
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

    func encodedData() throws -> Data {
        guard let source else { throw DocumentError.unreadable }
        return try ImageFiles.jpegData(from: source, ppi: ppi, quality: quality)
    }

    func rememberQuality() {
        UserDefaults.standard.set(quality, forKey: Self.qualityKey)
    }
}

struct JPEGExportSheet: View {
    @Bindable var model: JPEGExportViewModel
    let onExport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(L10n.JPEG.title)
                .font(.title2.bold())
            ZStack {
                Theme.canvasBackdrop
                if let preview = model.preview {
                    Image(decorative: preview, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(Theme.compactSpacing)
                }
                if model.preview == nil, !model.failed {
                    ProgressView()
                }
            }
            .frame(width: 480, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Text(L10n.JPEG.quality)
                Slider(value: $model.quality, in: 0.01...1, step: 0.01)
                Text(percent)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
            Text(L10n.JPEG.matte)
                .font(.callout)
                .foregroundStyle(Theme.secondaryLabel)
            HStack {
                if model.failed {
                    Text(L10n.Error.exportFailed)
                        .foregroundStyle(.red)
                } else if let byteCount = model.byteCount {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file))
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryLabel)
                } else {
                    Text(L10n.JPEG.updating)
                        .foregroundStyle(Theme.secondaryLabel)
                }
                Spacer()
                Button(L10n.Action.cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L10n.JPEG.export, action: onExport)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.byteCount == nil || model.failed)
            }
        }
        .padding(24)
        .frame(minWidth: 520)
        .task(id: model.quality) {
            try? await Task.sleep(for: .milliseconds(180))
            model.encode()
        }
    }

    private var percent: String {
        "\(Int((model.quality * 100).rounded()))%"
    }
}
