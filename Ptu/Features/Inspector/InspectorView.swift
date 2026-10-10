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
            ColorPicker(selection: foregroundBinding, supportsOpacity: false) {
                Text(L10n.Color.foreground)
            }
            ColorPicker(selection: backgroundBinding, supportsOpacity: false) {
                Text(L10n.Color.background)
            }
            Button {
                model.swapColors()
            } label: {
                Label(L10n.Color.swap, systemImage: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
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
                .onChange(of: nameFocused) { _, focused in
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

    private var foregroundBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: model.foreground.nsColor) },
            set: { model.foreground = RGBA(nsColor: NSColor($0)).opaque }
        )
    }

    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: model.background.nsColor) },
            set: { model.background = RGBA(nsColor: NSColor($0)).opaque }
        )
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
