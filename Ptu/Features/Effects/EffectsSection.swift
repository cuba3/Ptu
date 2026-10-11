// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct EffectsSection: View {
    @Bindable var model: InspectorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.compactSpacing) {
            Text(L10n.Effect.section)
                .font(.headline)
            ForEach(LayerEffectKind.allCases) { kind in
                Toggle(kind.title, isOn: Binding(
                    get: { model.isEffectEnabled(kind) },
                    set: { _ in model.toggleEffect(kind) }
                ))
            }
        }
    }
}

struct MaskSection: View {
    @Bindable var model: InspectorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.compactSpacing) {
            Text(L10n.Mask.section)
                .font(.headline)
            if model.hasMask {
                Toggle(L10n.MenuImage.enableMask, isOn: Binding(
                    get: { model.maskEnabled },
                    set: { model.setMaskEnabled($0) }
                ))
                Toggle(L10n.MenuImage.editMask, isOn: Binding(
                    get: { model.editsMask },
                    set: { model.editsMask = $0 }
                ))
                if model.editsMask {
                    Text(L10n.Mask.paintHint)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryLabel)
                }
                Button(L10n.MenuImage.invertMask) { model.invertMask() }
                Button(L10n.MenuImage.deleteMask) { model.deleteMask() }
            } else {
                Button(L10n.Mask.reveal) { model.addMask(revealing: true) }
                Button(L10n.Mask.hide) { model.addMask(revealing: false) }
            }
        }
    }
}
