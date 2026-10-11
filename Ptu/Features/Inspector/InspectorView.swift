// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

struct InspectorView: View {
    @Bindable var model: InspectorViewModel
    @State private var nameDraft = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            colorSection
            documentSection
            if model.hasSelectedLayer {
                layerSection
                if model.selectedIsPixel || model.selectedIsAdjustment {
                    MaskSection(model: model)
                }
                if model.selectedIsPixel {
                    EffectsSection(model: model)
                }
                if model.selectedIsAdjustment {
                    Button(L10n.Adjust.edit) {
                        model.onEditAdjustment?()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { nameDraft = model.selectedName }
        .onChange(of: model.selectedLayerID) { _, _ in
            nameDraft = model.selectedName
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Theme.compactSpacing) {
            Text(L10n.Color.section)
                .font(.headline)
            colorWell(title: L10n.Color.foreground, color: model.foreground) {
                model.pickColor(background: false)
            }
            colorWell(title: L10n.Color.background, color: model.background) {
                model.pickColor(background: true)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 18), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(Array(ColorPalette.swatches.enumerated()), id: \.offset) { _, swatch in
                    Button {
                        model.applySwatch(swatch)
                    } label: {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(nsColor: swatch.nsColor))
                            .frame(width: 18, height: 18)
                            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.35)) }
                    }
                    .buttonStyle(.plain)
                    .help(swatch.hex)
                }
            }
            HStack {
                Button {
                    model.swapColors()
                } label: {
                    Label(L10n.Color.swap, systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderless)
                Button(L10n.Color.reset) {
                    model.resetColors()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var documentSection: some View {
        VStack(alignment: .leading, spacing: Theme.compactSpacing) {
            Text(L10n.Inspector.document)
                .font(.headline)
            Text(L10n.Inspector.size(width: model.documentWidth, height: model.documentHeight))
            Text(L10n.Inspector.resolution(Int(model.resolutionPPI.rounded())))
                .foregroundStyle(Theme.secondaryLabel)
        }
    }

    private var layerSection: some View {
        VStack(alignment: .leading, spacing: Theme.compactSpacing) {
            TextField(L10n.Layer.name, text: $nameDraft)
                .focused($nameFocused)
                .onSubmit { model.setSelectedName(nameDraft) }
                .onDisappear { TextInsertionFocus.set("layer-name", active: false) }
                .onChange(of: nameFocused) { _, focused in
                    TextInsertionFocus.set("layer-name", active: focused)
                    model.nameFocusChanged(isFocused: focused, draft: nameDraft)
                }
                .onChange(of: nameDraft) { _, newValue in
                    model.nameDraftChanged(newValue, isFocused: nameFocused)
                }
            Picker(L10n.Layer.blend, selection: blendBinding) {
                ForEach(BlendMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            HStack {
                Text(L10n.Layer.opacity)
                Spacer(minLength: Theme.compactSpacing)
                Text(opacityBinding.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .foregroundStyle(Theme.secondaryLabel)
                    .monospacedDigit()
            }
            Slider(value: opacityBinding) { editing in
                model.opacityEditingChanged(editing)
            }
        }
    }

    private func colorWell(title: String, color: RGBA, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: color.nsColor))
                    .frame(width: 28, height: 28)
                    .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.35)) }
                Text(title)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var blendBinding: Binding<BlendMode> {
        Binding(
            get: { model.blend },
            set: { model.blend = $0 }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { model.opacity },
            set: { model.opacity = $0 }
        )
    }
}
