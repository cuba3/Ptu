// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct EditorActions {
    var canUndo: Bool
    var canRedo: Bool
    var undo: () -> Void
    var redo: () -> Void
    var deleteSelection: () -> Void
    var hasSelection: Bool
    var exportPNG: () -> Void
    var exportJPEG: () -> Void
    var zoomIn: () -> Void
    var zoomOut: () -> Void
    var actualSize: () -> Void
    var fit: () -> Void
}

private struct EditorActionsKey: FocusedValueKey {
    typealias Value = EditorActions
}

extension FocusedValues {
    var editorActions: EditorActions? {
        get { self[EditorActionsKey.self] }
        set { self[EditorActionsKey.self] = newValue }
    }
}

struct PtuCommands: Commands {
    @FocusedValue(\.editorActions) private var actions

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button {
                actions?.exportPNG()
            } label: {
                Text(L10n.Menu.exportPNG)
            }
            .disabled(actions == nil)
            Button {
                actions?.exportJPEG()
            } label: {
                Text(L10n.Menu.exportJPEG)
            }
            .disabled(actions == nil)
        }
        CommandGroup(replacing: .undoRedo) {
            Button {
                actions?.undo()
            } label: {
                Text(L10n.Edit.undo)
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(actions?.canUndo != true)
            Button {
                actions?.redo()
            } label: {
                Text(L10n.Edit.redo)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(actions?.canRedo != true)
            Divider()
            Button {
                actions?.deleteSelection()
            } label: {
                Text(L10n.Edit.deleteSelection)
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(actions?.hasSelection != true)
        }
        CommandGroup(after: .toolbar) {
            Button {
                actions?.zoomIn()
            } label: {
                Text(L10n.View.zoomIn)
            }
            .keyboardShortcut("=", modifiers: .command)
            .disabled(actions == nil)
            Button {
                actions?.zoomOut()
            } label: {
                Text(L10n.View.zoomOut)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(actions == nil)
            Button {
                actions?.actualSize()
            } label: {
                Text(L10n.View.actualSize)
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(actions == nil)
            Button {
                actions?.fit()
            } label: {
                Text(L10n.View.fit)
            }
            .keyboardShortcut("0", modifiers: [.command, .option])
            .disabled(actions == nil)
        }
    }
}
