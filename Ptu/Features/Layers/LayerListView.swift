// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct LayerListView: View {
    @Bindable var model: LayersViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.compactSpacing) {
            HStack {
                Text(L10n.Layer.section)
                    .font(.headline)
                Spacer(minLength: Theme.compactSpacing)
                Button {
                    model.addLayer()
                } label: {
                    Image(systemName: "plus")
                }
                .help(L10n.Layer.add)
                .buttonStyle(.borderless)
                Button {
                    model.addGroup()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help(L10n.Layer.addGroup)
                .buttonStyle(.borderless)
            }

            if model.layers.isEmpty {
                Text(L10n.Layer.empty)
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List(selection: selection) {
                    ForEach(model.layers) { node in
                        LayerRow(model: model, node: node)
                            .tag(node.id)
                    }
                    .onMove { offsets, destination in
                        model.moveRoot(from: offsets, to: destination)
                    }
                    .onDelete { offsets in
                        model.deleteRoot(at: offsets)
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 180)
            }

            HStack {
                Button {
                    model.bringForward()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .help(L10n.Layer.bringForward)
                Button {
                    model.sendBackward()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .help(L10n.Layer.sendBackward)
                Button {
                    model.duplicateSelected()
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .help(L10n.Layer.duplicate)
                Button(role: .destructive) {
                    model.deleteSelected()
                } label: {
                    Image(systemName: "trash")
                }
                .help(L10n.Layer.delete)
                Spacer(minLength: 0)
            }
            .buttonStyle(.borderless)
            .disabled(model.selectedLayerID == nil)
        }
    }

    private var selection: Binding<UUID?> {
        Binding(
            get: { model.selectedLayerID },
            set: { model.selectedLayerID = $0 }
        )
    }
}

private struct LayerRow: View {
    var model: LayersViewModel
    var node: LayerNode

    var body: some View {
        switch node {
        case .pixels(let layer):
            label(id: layer.id, name: layer.name, isVisible: layer.isVisible, symbol: layer.mask == nil ? "photo" : "photo.on.rectangle")
        case .adjustment(let layer):
            label(id: layer.id, name: layer.name, isVisible: layer.isVisible, symbol: "circle.lefthalf.filled")
        case .group(let group):
            DisclosureGroup {
                ForEach(group.children) { child in
                    LayerRow(model: model, node: child)
                        .tag(child.id)
                }
                .onMove { offsets, destination in
                    model.moveChildren(of: group.id, from: offsets, to: destination)
                }
            } label: {
                label(id: group.id, name: group.name, isVisible: group.isVisible, symbol: "folder")
            }
        }
    }

    private func label(id: UUID, name: String, isVisible: Bool, symbol: String) -> some View {
        HStack(spacing: Theme.compactSpacing) {
            Button {
                model.toggleVisible(id)
            } label: {
                Image(systemName: isVisible ? "eye" : "eye.slash")
            }
            .buttonStyle(.borderless)
            .help(isVisible ? L10n.Layer.hide : L10n.Layer.show)
            Image(systemName: symbol)
                .foregroundStyle(Theme.secondaryLabel)
            Text(name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
