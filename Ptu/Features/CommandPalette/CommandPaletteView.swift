// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct CommandPaletteView: View {
    @Bindable var model: CommandPaletteViewModel
    let onClose: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(L10n.Command.placeholder, text: $model.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($focused)
                .padding(Theme.spacing)
            Divider()
            if model.results.isEmpty {
                Text(L10n.Command.empty)
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(Theme.spacing)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, entry in
                                Button {
                                    guard entry.isEnabled else { return }
                                    entry.perform()
                                } label: {
                                    HStack {
                                        Text(entry.title)
                                            .foregroundStyle(entry.isEnabled ? Theme.label : Theme.secondaryLabel)
                                        Spacer()
                                        if let shortcut = entry.shortcut {
                                            Text(shortcut)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(Theme.secondaryLabel)
                                        }
                                    }
                                    .padding(.horizontal, Theme.spacing)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(index == model.selection ? Color.accentColor.opacity(0.18) : Color.clear)
                                }
                                .buttonStyle(.plain)
                                .disabled(!entry.isEnabled)
                                .id(index)
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: model.selection) { _, selection in
                        proxy.scrollTo(selection, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 520)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.separator) }
        .shadow(radius: 16)
        .onAppear { focused = true }
        .onChange(of: focused) { _, isFocused in
            TextInsertionFocus.set("command-palette", active: isFocused)
        }
        .onDisappear { TextInsertionFocus.set("command-palette", active: false) }
        .onKeyPress(.downArrow) {
            model.move(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            model.move(by: -1)
            return .handled
        }
        .onKeyPress(.return) {
            if let selected = model.selected, selected.isEnabled {
                selected.perform()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }
}
