// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ColorPickerViewModel {
    var isPresented = false
    var editingBackground = false
    var hsb = PickerHSB(hue: 0, saturation: 0, brightness: 0)
    var hexDraft = "000000"
    private var original: RGBA = .black
    private var onChange: (RGBA, Bool) -> Void = { _, _ in }

    var color: RGBA { hsb.color }

    func begin(color: RGBA, background: Bool, onChange: @escaping (RGBA, Bool) -> Void) {
        let opaque = color.opaque
        original = opaque
        hsb = PickerHSB(color: opaque)
        hexDraft = opaque.hex
        editingBackground = background
        self.onChange = onChange
        isPresented = true
    }

    func preview(_ hsb: PickerHSB) {
        self.hsb = hsb
        hexDraft = color.hex
        onChange(color, editingBackground)
    }

    func commitHex() {
        guard let parsed = RGBA(hex: hexDraft) else {
            hexDraft = color.hex
            return
        }
        preview(PickerHSB(color: parsed))
    }

    func chooseSwatch(_ swatch: RGBA) {
        preview(PickerHSB(color: swatch))
    }

    func confirm() {
        let chosen = color
        ColorPalette.remember(chosen)
        onChange(chosen, editingBackground)
        isPresented = false
    }

    func cancel() {
        onChange(original, editingBackground)
        isPresented = false
    }
}

struct ColorPickerSheet: View {
    @Bindable var model: ColorPickerViewModel
    private let fieldSize: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(model.editingBackground ? L10n.Color.background : L10n.Color.foreground)
                .font(.title2.bold())
            HStack(alignment: .top, spacing: Theme.spacing) {
                saturationField
                hueStrip
                VStack(alignment: .leading, spacing: Theme.compactSpacing) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: model.color.nsColor))
                        .frame(width: 72, height: 72)
                        .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.4)) }
                    channelField("R", model.color.r) { model.preview(PickerHSB(color: RGBA(r: $0, g: model.color.g, b: model.color.b, a: 255))) }
                    channelField("G", model.color.g) { model.preview(PickerHSB(color: RGBA(r: model.color.r, g: $0, b: model.color.b, a: 255))) }
                    channelField("B", model.color.b) { model.preview(PickerHSB(color: RGBA(r: model.color.r, g: model.color.g, b: $0, a: 255))) }
                    HStack {
                        Text("#")
                        TextField(L10n.Color.hex, text: $model.hexDraft)
                            .font(.body.monospaced())
                            .onSubmit { model.commitHex() }
                    }
                }
                .frame(width: 140)
            }
            swatchRow(title: L10n.Color.swatches, colors: ColorPalette.swatches)
            swatchRow(title: L10n.Color.recent, colors: ColorPalette.recent())
            HStack {
                Spacer()
                Button(L10n.Action.cancel) { model.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.Action.ok) { model.confirm() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 520)
    }

    private var saturationField: some View {
        let hueColor = PickerHSB(hue: model.hsb.hue, saturation: 1, brightness: 1).color
        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.white, Color(nsColor: hueColor.nsColor)], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
            Circle()
                .strokeBorder(.white, lineWidth: 1.5)
                .frame(width: 12, height: 12)
                .position(x: model.hsb.saturation * fieldSize, y: (1 - model.hsb.brightness) * fieldSize)
        }
        .frame(width: fieldSize, height: fieldSize)
        .clipShape(Rectangle())
        .overlay { Rectangle().strokeBorder(.black.opacity(0.45)) }
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            var next = model.hsb
            next.saturation = min(1, max(0, value.location.x / fieldSize))
            next.brightness = 1 - min(1, max(0, value.location.y / fieldSize))
            model.preview(next)
        })
        .accessibilityLabel(L10n.Color.saturationField)
    }

    private var hueStrip: some View {
        let markerY = (1 - model.hsb.hue / 360) * fieldSize
        return ZStack(alignment: .top) {
            LinearGradient(
                colors: stride(from: 0.0, through: 360, by: 60).map {
                    Color(nsColor: PickerHSB(hue: $0, saturation: 1, brightness: 1).color.nsColor)
                },
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(width: 18, height: fieldSize)
            .overlay { Rectangle().strokeBorder(.black.opacity(0.45)) }
            RoundedRectangle(cornerRadius: 1)
                .fill(.white)
                .frame(width: 22, height: 4)
                .offset(y: markerY - 2)
        }
        .frame(width: 28, height: fieldSize)
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            var next = model.hsb
            next.hue = (1 - min(1, max(0, value.location.y / fieldSize))) * 360
            model.preview(next)
        })
        .accessibilityLabel(L10n.Color.hue)
    }

    private func channelField(_ title: String, _ value: UInt8, set: @escaping (UInt8) -> Void) -> some View {
        HStack {
            Text(title)
                .frame(width: 14, alignment: .leading)
            TextField(title, value: Binding(
                get: { Int(value) },
                set: { set(UInt8(clamping: $0)) }
            ), format: .number)
            .frame(width: 64)
        }
    }

    private func swatchRow(title: String, colors: [RGBA]) -> some View {
        VStack(alignment: .leading, spacing: Theme.compactSpacing) {
            Text(title)
                .font(.headline)
            if colors.isEmpty {
                Text(L10n.Color.noRecent)
                    .foregroundStyle(Theme.secondaryLabel)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 22), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, swatch in
                        Button {
                            model.chooseSwatch(swatch)
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: swatch.nsColor))
                                .frame(width: 22, height: 22)
                                .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.35)) }
                        }
                        .buttonStyle(.plain)
                        .help(swatch.hex)
                    }
                }
            }
        }
    }
}
