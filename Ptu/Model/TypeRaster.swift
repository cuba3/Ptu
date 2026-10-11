// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import CoreGraphics
import Foundation

enum TypeRaster {
    struct Layout: Sendable {
        var buffer: PixelBuffer
        var caret: CGRect
    }

    static func render(text: String, fontSize: CGFloat, color: RGBA) -> Layout? {
        let size = min(2000, max(8, fontSize))
        let font = NSFont(name: "Helvetica", size: size) ?? NSFont.systemFont(ofSize: size)
        if text.isEmpty {
            let height = Int(ceil(size + 8))
            let buffer = PixelBuffer(width: max(8, Int(size * 0.4)), height: max(8, height), fill: .clear)
            return Layout(buffer: buffer, caret: CGRect(x: 4, y: 4, width: 1, height: size))
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(srgbRed: CGFloat(color.r) / 255, green: CGFloat(color.g) / 255, blue: CGFloat(color.b) / 255, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let padding: CGFloat = 8
        let measured = string.boundingRect(with: CGSize(width: 4000, height: 4000), options: [.usesLineFragmentOrigin, .usesFontLeading])
        let width = max(16, Int(ceil(measured.width + padding * 2)))
        let height = max(16, Int(ceil(max(measured.height, size) + padding * 2)))
        guard width * height <= 16_000 * 16_000 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        let storage = NSTextStorage(attributedString: string)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: CGFloat(width) - padding * 2, height: CGFloat(height) - padding * 2))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let glyphs = layout.glyphRange(for: container)
        layout.drawGlyphs(forGlyphRange: glyphs, at: CGPoint(x: padding, y: padding))
        NSGraphicsContext.current = nil
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage(), let buffer = PixelBuffer.from(cgImage: image) else { return nil }
        let caretX = min(CGFloat(width - 2), padding + measured.width)
        return Layout(buffer: buffer, caret: CGRect(x: caretX, y: padding, width: 1, height: size))
    }
}
