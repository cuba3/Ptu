// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

struct KeyboardShortcutsSheet: View {
    @ObservedObject private var store = ShortcutStore.shared
    @State private var draft: [String: ShortcutChord] = [:]
    @State private var recording: EditorCommandID?
    @State private var problem: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(L10n.Shortcuts.title)
                .font(.title2.bold())
            Text(recording == nil ? L10n.Shortcuts.hint : L10n.Shortcuts.recording)
                .foregroundStyle(Theme.secondaryLabel)
            List {
                Section(L10n.Shortcuts.groupMenu) {
                    ForEach(EditorCommandID.allCases.filter(\.isMenu)) { id in
                        row(id)
                    }
                }
                Section(L10n.Shortcuts.groupCanvas) {
                    ForEach(EditorCommandID.allCases.filter { !$0.isMenu }) { id in
                        row(id)
                    }
                }
            }
            if let problem {
                Text(problem)
                    .foregroundStyle(.red)
            }
            HStack {
                Button(L10n.Shortcuts.reset) {
                    draft = [:]
                    problem = nil
                    store.reset()
                }
                Spacer()
                Button(L10n.Shortcuts.save) { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 420)
        .onAppear { draft = store.overrides }
        .onDisappear { stopRecording() }
    }

    private func row(_ id: EditorCommandID) -> some View {
        HStack {
            Text(id.title)
            Spacer()
            Button(chord(for: id).label) {
                beginRecording(id)
            }
            .buttonStyle(.bordered)
        }
    }

    private func chord(for id: EditorCommandID) -> ShortcutChord {
        draft[id.rawValue] ?? id.defaultChord
    }

    private func beginRecording(_ id: EditorCommandID) {
        stopRecording()
        recording = id
        problem = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let chord = ShortcutChord(event)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.capture(keyCode: keyCode, chord: chord)
                }
            }
            return nil
        }
    }

    private func capture(keyCode: UInt16, chord: ShortcutChord) {
        guard let recording else { return }
        if keyCode == 53 {
            stopRecording()
            return
        }
        guard !chord.key.isEmpty else { return }
        draft[recording.rawValue] = chord
        stopRecording()
    }

    private func stopRecording() {
        recording = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func save() {
        if let problem = store.save(draft) {
            self.problem = problem
            return
        }
        problem = nil
        ShortcutPanel.close()
    }
}

@MainActor
enum ShortcutPanel {
    private static var window: NSWindow?

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: KeyboardShortcutsSheet())
        let panel = NSWindow(contentViewController: host)
        panel.title = L10n.Shortcuts.title
        panel.styleMask = [.titled, .closable, .resizable]
        panel.setContentSize(NSSize(width: 560, height: 520))
        panel.isReleasedWhenClosed = false
        window = panel
        panel.makeKeyAndOrderFront(nil)
    }

    static func close() {
        window?.close()
    }
}
