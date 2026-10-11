// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import Observation

struct DocumentTab: Identifiable {
    let id: UUID
    var title: String
    var activate: () -> Void
    var close: () -> Void
}

@MainActor
@Observable
final class DocumentTabCenter {
    static let shared: DocumentTabCenter = {
        let center = DocumentTabCenter()
        center.installMonitor()
        return center
    }()

    private(set) var tabs: [DocumentTab] = []
    var keyID: UUID?
    var keyHandler: ((EditorCommandID) -> Bool)?
    private var monitor: Any?
    private var keyWindow: NSWindow?
    private var textSession: (() -> Bool)?

    func register(title: String, activate: @escaping () -> Void, close: @escaping () -> Void) -> UUID {
        let id = UUID()
        tabs.append(DocumentTab(id: id, title: title, activate: activate, close: close))
        return id
    }

    func update(id: UUID, title: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].title = title
    }

    func unregister(id: UUID) {
        tabs.removeAll { $0.id == id }
        if keyID == id {
            keyID = nil
            keyHandler = nil
            keyWindow = nil
            textSession = nil
        }
    }

    func move(_ id: UUID, to index: Int) {
        guard let from = tabs.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(0, index), tabs.count - 1)
        guard target != from else { return }
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: target)
    }

    func becomeKey(
        id: UUID,
        window: NSWindow,
        handler: @escaping (EditorCommandID) -> Bool,
        isEditingText: @escaping () -> Bool
    ) {
        keyID = id
        keyWindow = window
        keyHandler = handler
        textSession = isEditingText
    }

    func resignKey(id: UUID) {
        guard keyID == id else { return }
        keyID = nil
        keyWindow = nil
        keyHandler = nil
        textSession = nil
    }

    /// Field editors, text fields, and SwiftUI text controls. Used so a focused insertion point keeps its keys.
    static func responderIsTextInsertion(_ responder: NSResponder?) -> Bool {
        guard let responder else { return false }
        if responder is NSText || responder is NSTextField { return true }
        let name = NSStringFromClass(type(of: responder))
        return name.contains("TextField") || name.contains("TextView") || name.contains("FieldEditor")
    }

    private func installMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return handled ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let window = event.window, window == keyWindow, window.attachedSheet == nil else { return false }
        let editing = (textSession?() ?? false)
            || TextInsertionFocus.shared.isActive
            || Self.responderIsTextInsertion(window.firstResponder)
        // A text view owns this event. Leave it for NSTextInputClient; do not insert characters here.
        if editing { return false }
        guard let command = ShortcutStore.shared.canvasCommand(for: event) else { return false }
        let chord = ShortcutStore.shared.chord(for: command)
        guard TextEditingGate.allowsCanvasCommand(command, modifiers: chord.modifiers, isEditingText: editing) else {
            return false
        }
        return keyHandler?(command) ?? false
    }
}
