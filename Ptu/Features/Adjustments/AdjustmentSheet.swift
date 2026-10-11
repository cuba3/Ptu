// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct AdjustmentSheet: View {
    @Bindable var model: AdjustmentViewModel
    var onApply: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(model.kind.title)
                .font(.headline)
            ScrollView {
                controls
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button(L10n.Action.cancel, action: onCancel)
                Button(L10n.Adjust.apply, action: onApply)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.spacing)
        .frame(minWidth: 360, minHeight: 280)
    }

    @ViewBuilder
    private var controls: some View {
        switch model.kind {
        case .levels:
            Picker(L10n.Adjust.channel, selection: $model.levels.channel) {
                ForEach(LevelsChannel.allCases) { channel in
                    Text(channel.title).tag(channel)
                }
            }
            slider(L10n.Adjust.black, level(\.black), 0...254)
            slider(L10n.Adjust.gamma, level(\.gamma), 0.1...9.99)
            slider(L10n.Adjust.white, level(\.white), 1...255)
            slider(L10n.Adjust.outputBlack, level(\.outputBlack), 0...255)
            slider(L10n.Adjust.outputWhite, level(\.outputWhite), 0...255)
        case .curves:
            Picker(L10n.Adjust.channel, selection: $model.curves.channel) {
                ForEach(LevelsChannel.allCases) { channel in
                    Text(channel.title).tag(channel)
                }
            }
            slider(L10n.Adjust.output, curveOutput, 0...255)
        case .hueSaturation:
            Picker(L10n.Adjust.hue, selection: $model.hue.range) {
                ForEach(ColorRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            Toggle(L10n.Adjust.colorize, isOn: $model.hue.colorize)
            slider(L10n.Adjust.hue, hueValue(.hue), model.hue.colorize ? 0...360 : -180...180)
            slider(L10n.Adjust.saturation, hueValue(.saturation), model.hue.colorize ? 0...100 : -100...100)
            slider(L10n.Adjust.lightness, hueValue(.lightness), -100...100)
        case .exposure:
            slider(L10n.Adjust.exposure, $model.exposure.exposure, -5...5)
            slider(L10n.Adjust.offset, $model.exposure.offset, -0.5...0.5)
            slider(L10n.Adjust.gamma, $model.exposure.gamma, 0.1...9.99)
        case .blackWhite:
            slider(L10n.Adjust.channelRed, $model.blackWhite.reds, -200...300)
            slider(L10n.Adjust.rangeYellows, $model.blackWhite.yellows, -200...300)
            slider(L10n.Adjust.rangeGreens, $model.blackWhite.greens, -200...300)
            slider(L10n.Adjust.rangeCyans, $model.blackWhite.cyans, -200...300)
            slider(L10n.Adjust.rangeBlues, $model.blackWhite.blues, -200...300)
            slider(L10n.Adjust.rangeMagentas, $model.blackWhite.magentas, -200...300)
            Toggle(L10n.Adjust.tint, isOn: $model.blackWhite.tint)
        case .colorBalance:
            slider(L10n.Adjust.cyanRed, $model.colorBalance.midCyanRed, -100...100)
            slider(L10n.Adjust.magentaGreen, $model.colorBalance.midMagentaGreen, -100...100)
            slider(L10n.Adjust.yellowBlue, $model.colorBalance.midYellowBlue, -100...100)
            Toggle(L10n.Adjust.preserveLuminosity, isOn: $model.colorBalance.preserveLuminosity)
        case .gradientMap:
            ColorPicker(L10n.Adjust.shadows, selection: shadowColor, supportsOpacity: false)
            ColorPicker(L10n.Adjust.highlights, selection: highlightColor, supportsOpacity: false)
            Toggle(L10n.Adjust.reversed, isOn: $model.gradientMap.reversed)
        case .grain:
            slider(L10n.Adjust.amount, $model.grain.amount, 0...100)
            slider(L10n.Adjust.size, $model.grain.size, 0.5...20)
            slider(L10n.Adjust.roughness, $model.grain.roughness, 0...100)
        case .gaussianBlur:
            slider(L10n.Filter.radius, $model.filter.radius, 0.1...100)
        case .motionBlur:
            slider(L10n.Filter.angle, $model.filter.angle, -90...90)
            slider(L10n.Filter.distance, $model.filter.distance, 1...200)
        case .addNoise:
            slider(L10n.Adjust.amount, $model.filter.amount, 0.1...100)
            Toggle(L10n.Filter.gaussianNoise, isOn: $model.filter.gaussian)
            Toggle(L10n.Filter.monochromatic, isOn: $model.filter.monochromatic)
        case .vignette:
            slider(L10n.Adjust.amount, $model.filter.vignetteAmount, 0...100)
            slider(L10n.Adjust.feather, $model.filter.vignetteFeather, 0...100)
        case .bloomGlow:
            slider(L10n.Adjust.amount, $model.filter.bloomAmount, 0...100)
            slider(L10n.Filter.radius, $model.filter.bloomRadius, 1...80)
        case .tonalContrast:
            slider(L10n.Adjust.amount, $model.filter.tonalAmount, 0...100)
            slider(L10n.Filter.radius, $model.filter.tonalRadius, 1...40)
        case .dither:
            Picker(L10n.Dither.style, selection: $model.filter.dither.style) {
                ForEach(DitherStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            slider(L10n.Dither.levels, $model.filter.dither.levels, 2...8)
            slider(L10n.Adjust.size, $model.filter.dither.pixelSize, 1...16)
        case .lensCorrection:
            slider(L10n.Filter.distortion, $model.filter.distortion, -100...100)
        case .cameraRaw:
            slider(L10n.Adjust.exposure, $model.cameraRaw.exposure, -5...5)
            slider(L10n.Adjust.contrast, $model.cameraRaw.contrast, -100...100)
            slider(L10n.Adjust.highlights, $model.cameraRaw.highlights, -100...100)
            slider(L10n.Adjust.shadows, $model.cameraRaw.shadows, -100...100)
            slider(L10n.Adjust.whites, $model.cameraRaw.whites, -100...100)
            slider(L10n.Adjust.blacks, $model.cameraRaw.blacks, -100...100)
            slider(L10n.Adjust.temperature, $model.cameraRaw.temperature, -100...100)
            slider(L10n.Adjust.tint, $model.cameraRaw.tint, -100...100)
            slider(L10n.Adjust.vibrance, $model.cameraRaw.vibrance, -100...100)
            slider(L10n.Adjust.saturation, $model.cameraRaw.saturation, -100...100)
            slider(L10n.Adjust.dehaze, $model.cameraRaw.dehaze, -100...100)
            slider(L10n.Adjust.sharpen, $model.cameraRaw.detail.sharpenAmount, 0...150)
            slider(L10n.Adjust.grain, $model.cameraRaw.grainAmount, 0...100)
        case .rawDevelop:
            slider(L10n.Adjust.exposure, rawExposure, -3...3)
            slider(L10n.Adjust.temperature, rawTemperature, 2000...10000)
            slider(L10n.Adjust.tint, rawTint, -150...150)
            slider(L10n.Adjust.boost, rawBoost, 0...1)
            Button(L10n.Adjust.reset) { model.resetRaw() }
        }
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(0...2)))
                    .foregroundStyle(Theme.secondaryLabel)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }

    private func level(_ keyPath: WritableKeyPath<LevelRange, Double>) -> Binding<Double> {
        Binding(
            get: { model.levels.ranges[model.levels.channel.index][keyPath: keyPath] },
            set: { newValue in
                model.levels.ranges[model.levels.channel.index][keyPath: keyPath] = newValue
            }
        )
    }

    private enum HueField { case hue, saturation, lightness }

    private func hueValue(_ field: HueField) -> Binding<Double> {
        Binding(
            get: {
                switch field {
                case .hue: model.hue.hue
                case .saturation: model.hue.saturation
                case .lightness: model.hue.lightness
                }
            },
            set: { newValue in
                var settings = model.hue
                switch field {
                case .hue: settings.hue = newValue
                case .saturation: settings.saturation = newValue
                case .lightness: settings.lightness = newValue
                }
                model.hue = settings
            }
        )
    }

    private var curveOutput: Binding<Double> {
        Binding(
            get: { model.curves.channels[model.curves.channel.index].last?.y ?? 255 },
            set: { newValue in
                let index = model.curves.channel.index
                guard var last = model.curves.channels[index].last else { return }
                last.y = min(255, max(0, newValue))
                model.curves.channels[index][model.curves.channels[index].count - 1] = last
            }
        )
    }

    private var shadowColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: model.gradientMap.shadows.rgba.nsColor) },
            set: { model.gradientMap.shadows = AdjustmentColor(RGBA(nsColor: NSColor($0))) }
        )
    }

    private var highlightColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: model.gradientMap.highlights.rgba.nsColor) },
            set: { model.gradientMap.highlights = AdjustmentColor(RGBA(nsColor: NSColor($0))) }
        )
    }

    private var rawExposure: Binding<Double> {
        Binding(get: { Double(model.raw.exposure) }, set: { model.raw.exposure = Float($0) })
    }

    private var rawTemperature: Binding<Double> {
        Binding(get: { Double(model.raw.temperature) }, set: { model.raw.temperature = Float($0) })
    }

    private var rawTint: Binding<Double> {
        Binding(get: { Double(model.raw.tint) }, set: { model.raw.tint = Float($0) })
    }

    private var rawBoost: Binding<Double> {
        Binding(get: { Double(model.raw.boost) }, set: { model.raw.boost = Float($0) })
    }
}
