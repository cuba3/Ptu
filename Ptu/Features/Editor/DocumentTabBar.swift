// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

struct DocumentTabBar: View {
    @Bindable var center: DocumentTabCenter
    private let plusWidth: CGFloat = 36

    var body: some View {
        GeometryReader { geometry in
            let widths = Dictionary(uniqueKeysWithValues: center.tabs.map { ($0.id, Self.width(for: $0.title)) })
            let selected = center.keyID ?? center.tabs.first?.id ?? UUID()
            let layout = DocumentTabLayout.overflow(
                order: center.tabs.map(\.id),
                widths: widths,
                selectedID: selected,
                availableWidth: max(0, geometry.size.width - plusWidth),
                pillWidth: { _ in 88 }
            )
            HStack(spacing: documentTabSpacing) {
                if layout.pill != nil {
                    Menu {
                        ForEach(layout.hiddenIDs, id: \.self) { id in
                            if let tab = center.tabs.first(where: { $0.id == id }) {
                                Button(tab.title) { tab.activate() }
                            }
                        }
                    } label: {
                        Text(L10n.Tabs.overflow(layout.hiddenIDs.count))
                    }
                    .frame(width: 88)
                }
                ForEach(layout.visible) { slot in
                    if let tab = center.tabs.first(where: { $0.id == slot.id }) {
                        tabButton(tab, selected: tab.id == center.keyID)
                            .frame(width: slot.width)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    NSDocumentController.shared.newDocument(nil)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(L10n.Tabs.new)
                .frame(width: 28)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 34)
        .background(.bar)
    }

    private func tabButton(_ tab: DocumentTab, selected: Bool) -> some View {
        HStack(spacing: 4) {
            Button(tab.title) { tab.activate() }
                .buttonStyle(.plain)
                .lineLimit(1)
            Button {
                tab.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.borderless)
            .help(L10n.Tabs.close)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05), in: Capsule())
        .draggable(tab.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw),
                  let index = center.tabs.firstIndex(where: { $0.id == tab.id }) else { return false }
            center.move(id, to: index)
            return true
        }
    }

    static func width(for title: String) -> CGFloat {
        min(180, max(96, CGFloat(title.count) * 8 + 44))
    }
}

struct EditorWindowReader: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window { onResolve(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            if let window = nsView?.window { onResolve(window) }
        }
    }
}
