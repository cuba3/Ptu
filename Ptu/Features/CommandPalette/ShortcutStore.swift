// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

struct ShortcutChord: Codable, Equatable, Hashable {
    var key: String
    var modifiers: Int

    init(_ key: String, _ modifiers: Int = 0) {
        self.key = key
        self.modifiers = modifiers
    }

    init(_ event: NSEvent) {
        let flags = event.modifierFlags
        modifiers = (flags.contains(.command) ? 1 : 0)
            | (flags.contains(.option) ? 2 : 0)
            | (flags.contains(.control) ? 4 : 0)
            | (flags.contains(.shift) ? 8 : 0)
        switch event.keyCode {
        case 51, 117: key = "\u{7f}"
        case 36, 76: key = "\r"
        case 53: key = "\u{1b}"
        case 48: key = "\t"
        case 49: key = " "
        case 123: key = "\u{f702}"
        case 124: key = "\u{f703}"
        case 125: key = "\u{f701}"
        case 126: key = "\u{f700}"
        default:
            let typed = event.charactersIgnoringModifiers?.lowercased() ?? ""
            key = ["{": "[", "}": "]", "+": "=", "_": "-"][typed] ?? typed
        }
    }

    var eventModifiers: EventModifiers {
        var flags: EventModifiers = []
        if modifiers & 1 != 0 { flags.insert(.command) }
        if modifiers & 2 != 0 { flags.insert(.option) }
        if modifiers & 4 != 0 { flags.insert(.control) }
        if modifiers & 8 != 0 { flags.insert(.shift) }
        return flags
    }

    var keyEquivalent: KeyEquivalent {
        switch key {
        case "\u{7f}": .delete
        case "\u{1b}": .escape
        case "\r": .return
        case "\t": .tab
        case " ": .space
        case "\u{f702}": .leftArrow
        case "\u{f703}": .rightArrow
        case "\u{f701}": .downArrow
        case "\u{f700}": .upArrow
        default:
            KeyEquivalent(key.first ?? " ")
        }
    }

    var label: String {
        let special = [
            "\u{7f}": L10n.Shortcuts.deleteKey,
            "\r": L10n.Shortcuts.returnKey,
            "\u{1b}": L10n.Shortcuts.escapeKey,
            "\t": L10n.Shortcuts.tabKey,
            " ": L10n.Shortcuts.spaceKey,
            "\u{f702}": "←",
            "\u{f703}": "→",
            "\u{f701}": "↓",
            "\u{f700}": "↑",
        ]
        return (modifiers & 4 != 0 ? "⌃" : "")
            + (modifiers & 2 != 0 ? "⌥" : "")
            + (modifiers & 8 != 0 ? "⇧" : "")
            + (modifiers & 1 != 0 ? "⌘" : "")
            + (special[key] ?? key.uppercased())
    }
}

enum EditorCommandID: String, CaseIterable, Identifiable {
    case undo
    case redo
    case exportPNG
    case exportJPEG
    case importPSD
    case reload
    case commandPalette
    case zoomIn
    case zoomOut
    case actualSize
    case fit
    case deleteSelection
    case swapColors
    case resetColors
    case toolMove
    case toolMarquee
    case toolBrush
    case toolCrop
    case toolEyedropper
    case newLayer
    case newGroup
    case duplicateLayer
    case deleteLayer
    case bringForward
    case sendBackward

    var id: String { rawValue }

    var isMenu: Bool {
        switch self {
        case .undo, .redo, .exportPNG, .exportJPEG, .importPSD, .reload, .commandPalette,
             .zoomIn, .zoomOut, .actualSize, .fit, .deleteSelection:
            true
        default:
            false
        }
    }

    var title: String {
        switch self {
        case .undo: L10n.Edit.undo
        case .redo: L10n.Edit.redo
        case .exportPNG: L10n.Menu.exportPNG
        case .exportJPEG: L10n.Menu.exportJPEG
        case .importPSD: L10n.Menu.importPSD
        case .reload: L10n.Menu.reload
        case .commandPalette: L10n.Menu.commandPalette
        case .zoomIn: L10n.View.zoomIn
        case .zoomOut: L10n.View.zoomOut
        case .actualSize: L10n.View.actualSize
        case .fit: L10n.View.fit
        case .deleteSelection: L10n.Edit.deleteSelection
        case .swapColors: L10n.Color.swap
        case .resetColors: L10n.Color.reset
        case .toolMove: L10n.Tool.move
        case .toolMarquee: L10n.Tool.marquee
        case .toolBrush: L10n.Tool.brush
        case .toolCrop: L10n.Tool.crop
        case .toolEyedropper: L10n.Tool.eyedropper
        case .newLayer: L10n.Layer.add
        case .newGroup: L10n.Layer.addGroup
        case .duplicateLayer: L10n.Layer.duplicate
        case .deleteLayer: L10n.Layer.delete
        case .bringForward: L10n.Layer.bringForward
        case .sendBackward: L10n.Layer.sendBackward
        }
    }

    var defaultChord: ShortcutChord {
        switch self {
        case .undo: ShortcutChord("z", 1)
        case .redo: ShortcutChord("z", 9)
        case .exportPNG: ShortcutChord("e", 9)
        case .exportJPEG: ShortcutChord("e", 3)
        case .importPSD: ShortcutChord("i", 9)
        case .reload: ShortcutChord("r", 3)
        case .commandPalette: ShortcutChord("k", 1)
        case .zoomIn: ShortcutChord("=", 1)
        case .zoomOut: ShortcutChord("-", 1)
        case .actualSize: ShortcutChord("0", 1)
        case .fit: ShortcutChord("0", 3)
        case .deleteSelection: ShortcutChord("\u{7f}")
        case .swapColors: ShortcutChord("x")
        case .resetColors: ShortcutChord("d")
        case .toolMove: ShortcutChord("v")
        case .toolMarquee: ShortcutChord("m")
        case .toolBrush: ShortcutChord("b")
        case .toolCrop: ShortcutChord("c")
        case .toolEyedropper: ShortcutChord("i")
        case .newLayer: ShortcutChord("n", 9)
        case .newGroup: ShortcutChord("g", 1)
        case .duplicateLayer: ShortcutChord("j", 1)
        case .deleteLayer: ShortcutChord("\u{7f}", 1)
        case .bringForward: ShortcutChord("]", 1)
        case .sendBackward: ShortcutChord("[", 1)
        }
    }
}

@MainActor
final class ShortcutStore: ObservableObject {
    static let shared: ShortcutStore = {
        let store = ShortcutStore()
        store.loadFromDefaults()
        return store
    }()

    static let storageKey = "ptu.shortcuts.v1"

    @Published private(set) var overrides: [String: ShortcutChord] = [:]

    init(overrides: [String: ShortcutChord] = [:]) {
        self.overrides = overrides
    }

    func chord(for id: EditorCommandID) -> ShortcutChord {
        overrides[id.rawValue] ?? id.defaultChord
    }

    func canvasCommand(for event: NSEvent) -> EditorCommandID? {
        let chord = ShortcutChord(event)
        return EditorCommandID.allCases.first { !$0.isMenu && self.chord(for: $0) == chord }
    }

    func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode([String: ShortcutChord].self, from: data),
              Self.problem(in: saved) == nil else { return }
        overrides = saved
    }

    @discardableResult
    func save(_ values: [String: ShortcutChord]) -> String? {
        if let problem = Self.problem(in: values) { return problem }
        overrides = values
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        return nil
    }

    func reset() {
        overrides = [:]
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    static func problem(in values: [String: ShortcutChord]) -> String? {
        var assigned: [ShortcutChord: EditorCommandID] = [:]
        for id in EditorCommandID.allCases {
            let chord = values[id.rawValue] ?? id.defaultChord
            guard chord.key.count == 1, (0...15).contains(chord.modifiers) else {
                return L10n.Shortcuts.singleKey
            }
            if id.isMenu, chord.modifiers & 5 == 0, chord.key.first?.isLetter == true || chord.key == "=" || chord.key == "-" || chord.key == "0" {
                return L10n.Shortcuts.needsModifier
            }
            if [ShortcutChord("q", 1), ShortcutChord(",", 1), ShortcutChord("m", 5)].contains(chord) {
                return L10n.Shortcuts.reserved(chord.label)
            }
            if let other = assigned[chord] {
                return L10n.Shortcuts.duplicate(chord.label, other.title, id.title)
            }
            assigned[chord] = id
        }
        return nil
    }
}

/// Decides whether an app shortcut may run. Callers pass the editing flag; this does not look at AppKit focus.
enum TextEditingGate {
    /// Every shortcut command is ignored while text is edited. Copy, paste, cut, and select-all are not commands here.
    static func allowsCanvasCommand(_ id: EditorCommandID, modifiers: Int, isEditingText: Bool) -> Bool {
        _ = (id, modifiers)
        return !isEditingText
    }

    /// Plain shelf keys. Shift is ignored by the caller; command, option, and control are not shelf switches.
    static func shelfTool(for characters: String, isEditingText: Bool) -> EditorTool? {
        guard !isEditingText else { return nil }
        switch characters.lowercased() {
        case "h": return .hand
        case "z": return .zoom
        case "v": return .move
        case "m": return .marquee
        case "b": return .brush
        case "c": return .crop
        case "i": return .eyedropper
        default: return nil
        }
    }
}

/// Sidebar and overlay fields, so the key monitor can leave their keystrokes alone.
@MainActor
final class TextInsertionFocus: ObservableObject {
    static let shared = TextInsertionFocus()

    @Published private(set) var isActive = false
    private var sources: Set<String> = []

    static func set(_ id: String, active: Bool) {
        shared.update(id, active: active)
    }

    private func update(_ id: String, active: Bool) {
        if active {
            sources.insert(id)
        } else {
            sources.remove(id)
        }
        let now = !sources.isEmpty
        if isActive != now {
            isActive = now
        }
    }
}
