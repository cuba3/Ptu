// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
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
    var importPSD: () -> Void
    var reload: () -> Void
    var canReload: Bool
    var showCommandPalette: () -> Void
    var showShortcuts: () -> Void
    var canEditPixels: Bool
    var canMask: Bool
    var hasMask: Bool
    var maskEnabled: Bool
    var editsMask: Bool
    var performImage: (ImageCommand) -> Void
    var selectAll: () -> Void
    var deselect: () -> Void
    var inverseSelection: () -> Void
    var featherSelection: () -> Void
    var copySelection: () -> Void
    var cutSelection: () -> Void
    var pasteSelection: () -> Void
    var floatSelection: () -> Void
    var contentAwareFill: () -> Void
    var selectSubject: () -> Void
    var removeBackground: () -> Void
    var canPaste: Bool
    var performGeometry: (GeometryCommand) -> Void
    var showsRulers: Bool
    var showsGuides: Bool
    var showsGrid: Bool
    var snapEnabled: Bool
    var isTransforming: Bool
    var isEditingText: Bool
    var deleteTypeCharacter: () -> Void
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
    @ObservedObject private var shortcuts = ShortcutStore.shared
    @ObservedObject private var recents = RecentFiles.shared
    @ObservedObject private var textInsertion = TextInsertionFocus.shared

    private var shortcutsSuspended: Bool {
        actions?.isEditingText == true || textInsertion.isActive
    }

    private func shortcutBlocked(_ inactive: Bool) -> Bool {
        shortcutsSuspended || inactive
    }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Menu(L10n.Menu.openRecent) {
                if recents.urls.isEmpty {
                    Button(L10n.Menu.noRecent) {}
                        .disabled(true)
                } else {
                    ForEach(recents.urls, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            RecentFiles.shared.open(url)
                        }
                    }
                }
                Divider()
                Button(L10n.Menu.clearRecent) {
                    RecentFiles.shared.clear()
                }
            }
            Button(L10n.Menu.importPSD) {
                actions?.importPSD()
            }
            .keyboardShortcut(shortcuts.chord(for: .importPSD).keyEquivalent, modifiers: shortcuts.chord(for: .importPSD).eventModifiers)
            .disabled(shortcutBlocked(actions == nil))
            Button(L10n.Menu.reload) {
                actions?.reload()
            }
            .keyboardShortcut(shortcuts.chord(for: .reload).keyEquivalent, modifiers: shortcuts.chord(for: .reload).eventModifiers)
            .disabled(shortcutBlocked(actions?.canReload != true))
        }
        CommandGroup(after: .saveItem) {
            Button {
                actions?.exportPNG()
            } label: {
                Text(L10n.Menu.exportPNG)
            }
            .keyboardShortcut(shortcuts.chord(for: .exportPNG).keyEquivalent, modifiers: shortcuts.chord(for: .exportPNG).eventModifiers)
            .disabled(shortcutBlocked(actions == nil))
            Button {
                actions?.exportJPEG()
            } label: {
                Text(L10n.Menu.exportJPEG)
            }
            .keyboardShortcut(shortcuts.chord(for: .exportJPEG).keyEquivalent, modifiers: shortcuts.chord(for: .exportJPEG).eventModifiers)
            .disabled(shortcutBlocked(actions == nil))
        }
        CommandGroup(replacing: .undoRedo) {
            Button {
                actions?.undo()
            } label: {
                Text(L10n.Edit.undo)
            }
            .keyboardShortcut(shortcuts.chord(for: .undo).keyEquivalent, modifiers: shortcuts.chord(for: .undo).eventModifiers)
            .disabled(shortcutBlocked(actions?.canUndo != true))
            Button {
                actions?.redo()
            } label: {
                Text(L10n.Edit.redo)
            }
            .keyboardShortcut(shortcuts.chord(for: .redo).keyEquivalent, modifiers: shortcuts.chord(for: .redo).eventModifiers)
            .disabled(shortcutBlocked(actions?.canRedo != true))
            Divider()
            Button {
                if TextFieldKeys.send(#selector(NSText.deleteBackward(_:))) { return }
                if actions?.isEditingText == true {
                    actions?.deleteTypeCharacter()
                    return
                }
                actions?.deleteSelection()
            } label: {
                Text(L10n.Edit.deleteSelection)
            }
            .keyboardShortcut(shortcuts.chord(for: .deleteSelection).keyEquivalent, modifiers: shortcuts.chord(for: .deleteSelection).eventModifiers)
            .disabled(shortcutBlocked(actions?.hasSelection != true))
            Divider()
            Button(L10n.Menu.commandPalette) {
                actions?.showCommandPalette()
            }
            .keyboardShortcut(shortcuts.chord(for: .commandPalette).keyEquivalent, modifiers: shortcuts.chord(for: .commandPalette).eventModifiers)
            .disabled(shortcutBlocked(actions == nil))
            Button(L10n.Menu.keyboardShortcuts) {
                ShortcutPanel.show()
            }
        }
        CommandMenu(L10n.Selection.menu) {
            Button(L10n.Selection.all) {
                if TextFieldKeys.send(#selector(NSText.selectAll(_:))) { return }
                actions?.selectAll()
            }
                .keyboardShortcut("a", modifiers: .command)
                .disabled(actions == nil)
            Button(L10n.Selection.deselect) { actions?.deselect() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(shortcutBlocked(actions?.hasSelection != true))
            Button(L10n.Selection.inverse) { actions?.inverseSelection() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(shortcutBlocked(actions?.hasSelection != true))
            Button(L10n.Selection.feather) { actions?.featherSelection() }
                .disabled(actions?.hasSelection != true)
            Divider()
            Button(L10n.Selection.copy) {
                if TextFieldKeys.send(#selector(NSText.copy(_:))) { return }
                actions?.copySelection()
            }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(actions == nil)
            Button(L10n.Selection.cut) {
                if TextFieldKeys.send(#selector(NSText.cut(_:))) { return }
                actions?.cutSelection()
            }
                .keyboardShortcut("x", modifiers: .command)
                .disabled(actions?.hasSelection != true)
            Button(L10n.Selection.paste) {
                if TextFieldKeys.send(#selector(NSText.paste(_:))) { return }
                actions?.pasteSelection()
            }
                .keyboardShortcut("v", modifiers: .command)
                .disabled(actions?.canPaste != true && actions?.isEditingText != true)
            Button(L10n.Selection.floatSelection) { actions?.floatSelection() }
                .disabled(actions?.hasSelection != true)
            Divider()
            Button(L10n.Selection.contentFill) { actions?.contentAwareFill() }
                .disabled(actions?.hasSelection != true)
            Button(L10n.Selection.subject) { actions?.selectSubject() }
                .disabled(actions == nil)
            Button(L10n.Selection.removeBackground) { actions?.removeBackground() }
                .disabled(actions == nil)
        }
        CommandGroup(after: .toolbar) {
            Button {
                actions?.zoomIn()
            } label: {
                Text(L10n.View.zoomIn)
            }
            .keyboardShortcut(shortcuts.chord(for: .zoomIn).keyEquivalent, modifiers: shortcuts.chord(for: .zoomIn).eventModifiers)
            .disabled(shortcutBlocked(actions == nil))
            Button {
                actions?.zoomOut()
            } label: {
                Text(L10n.View.zoomOut)
            }
            .keyboardShortcut(shortcuts.chord(for: .zoomOut).keyEquivalent, modifiers: shortcuts.chord(for: .zoomOut).eventModifiers)
            .disabled(shortcutBlocked(actions == nil))
            Button {
                actions?.actualSize()
            } label: {
                Text(L10n.View.actualSize)
            }
            .keyboardShortcut(shortcuts.chord(for: .actualSize).keyEquivalent, modifiers: shortcuts.chord(for: .actualSize).eventModifiers)
            .disabled(shortcutBlocked(actions == nil))
            Button {
                actions?.fit()
            } label: {
                Text(L10n.View.fit)
            }
            .keyboardShortcut(shortcuts.chord(for: .fit).keyEquivalent, modifiers: shortcuts.chord(for: .fit).eventModifiers)
            .disabled(shortcutBlocked(actions == nil))
            Divider()
            Button(L10n.Geometry.rulers) { actions?.performGeometry(.toggleRulers) }
                .disabled(actions == nil)
            Button(L10n.Geometry.guides) { actions?.performGeometry(.toggleGuides) }
                .disabled(actions == nil)
            Button(L10n.Geometry.grid) { actions?.performGeometry(.toggleGrid) }
                .disabled(actions == nil)
            Button(L10n.Geometry.gridSettings) { actions?.performGeometry(.gridSettings) }
                .disabled(actions == nil)
            Button(L10n.Geometry.snap) { actions?.performGeometry(.toggleSnap) }
                .disabled(actions == nil)
            Button(L10n.Geometry.clearGuides) { actions?.performGeometry(.clearGuides) }
                .disabled(actions == nil)
            Button(L10n.Geometry.addHorizontalGuide) { actions?.performGeometry(.addHorizontalGuide) }
                .disabled(actions == nil)
            Button(L10n.Geometry.addVerticalGuide) { actions?.performGeometry(.addVerticalGuide) }
                .disabled(actions == nil)
            Button(L10n.Geometry.hand) { actions?.performGeometry(.hand) }
                .disabled(actions == nil)
            Button(L10n.Geometry.zoomTool) { actions?.performGeometry(.zoom) }
                .disabled(actions == nil)
        }
        CommandMenu(L10n.Geometry.transform) {
            Button(L10n.Geometry.freeTransform) { actions?.performGeometry(.freeTransform) }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(shortcutBlocked(actions?.canEditPixels != true))
            Button(L10n.Geometry.distort) { actions?.performGeometry(.distort) }
                .disabled(actions?.canEditPixels != true)
            Button(L10n.Geometry.apply) { actions?.performGeometry(.applyTransform) }
                .disabled(actions?.isTransforming != true)
            Button(L10n.Geometry.cancel) { actions?.performGeometry(.cancelTransform) }
                .disabled(actions?.isTransforming != true)
            Divider()
            Button(L10n.Geometry.flipHorizontal) { actions?.performGeometry(.flipHorizontal) }
                .disabled(actions?.canEditPixels != true)
            Button(L10n.Geometry.flipVertical) { actions?.performGeometry(.flipVertical) }
                .disabled(actions?.canEditPixels != true)
            Divider()
            Button(L10n.Geometry.flipCanvasHorizontal) { actions?.performGeometry(.flipCanvasHorizontal) }
                .disabled(actions == nil)
            Button(L10n.Geometry.flipCanvasVertical) { actions?.performGeometry(.flipCanvasVertical) }
                .disabled(actions == nil)
            Button(L10n.Geometry.rotateClockwise) { actions?.performGeometry(.rotateClockwise) }
                .disabled(actions == nil)
            Button(L10n.Geometry.rotateCounterclockwise) { actions?.performGeometry(.rotateCounterclockwise) }
                .disabled(actions == nil)
            Button(L10n.Geometry.rotate180) { actions?.performGeometry(.rotate180) }
                .disabled(actions == nil)
            Divider()
            Button(L10n.Geometry.imageSize) { actions?.performGeometry(.imageSize) }
                .disabled(actions == nil)
            Button(L10n.Geometry.canvasSize) { actions?.performGeometry(.canvasSize) }
                .disabled(actions == nil)
            Button(L10n.Geometry.trim) { actions?.performGeometry(.trim) }
                .disabled(actions == nil)
        }
        CommandMenu(L10n.MenuImage.menu) {
            imageButton(.bake(.levels), L10n.MenuImage.levels, pixels: true)
            imageButton(.bake(.curves), L10n.MenuImage.curves, pixels: true)
            imageButton(.bake(.hueSaturation), L10n.MenuImage.hueSaturation, pixels: true)
            imageButton(.bake(.exposure), L10n.MenuImage.exposure, pixels: true)
            imageButton(.bake(.blackWhite), L10n.MenuImage.blackWhite, pixels: true)
            imageButton(.bake(.colorBalance), L10n.MenuImage.colorBalance, pixels: true)
            imageButton(.bake(.gradientMap), L10n.MenuImage.gradientMap, pixels: true)
            imageButton(.bake(.grain), L10n.MenuImage.grain, pixels: true)
            imageButton(.invert, L10n.MenuImage.invert, pixels: true)
            Divider()
            imageButton(.bake(.cameraRaw), L10n.MenuImage.cameraRaw, pixels: true)
            Button(L10n.MenuImage.developRaw) { actions?.performImage(.developRaw) }
                .disabled(actions == nil)
        }
        CommandMenu(L10n.MenuImage.filter) {
            imageButton(.bake(.gaussianBlur), L10n.MenuImage.gaussianBlur, pixels: true)
            imageButton(.bake(.motionBlur), L10n.MenuImage.motionBlur, pixels: true)
            imageButton(.bake(.addNoise), L10n.MenuImage.addNoise, pixels: true)
            imageButton(.bake(.vignette), L10n.MenuImage.vignette, pixels: true)
            imageButton(.bake(.bloomGlow), L10n.MenuImage.bloom, pixels: true)
            imageButton(.bake(.tonalContrast), L10n.MenuImage.tonalContrast, pixels: true)
            imageButton(.bake(.dither), L10n.MenuImage.dither, pixels: true)
            imageButton(.bake(.lensCorrection), L10n.MenuImage.lensCorrection, pixels: true)
        }
        CommandMenu(L10n.MenuImage.layer) {
            imageButton(.addMask, L10n.MenuImage.addMask, pixels: false)
            imageButton(.deleteMask, L10n.MenuImage.deleteMask, pixels: false)
            imageButton(.invertMask, L10n.MenuImage.invertMask, pixels: false)
            Button(actions?.maskEnabled == true ? L10n.MenuImage.disableMask : L10n.MenuImage.enableMask) {
                actions?.performImage(.toggleMask)
            }
            .disabled(actions?.hasMask != true)
            Button(L10n.MenuImage.editMask) { actions?.performImage(.editMask) }
                .disabled(actions?.hasMask != true)
            Divider()
            imageButton(.clippingMask, L10n.MenuImage.clippingMask, pixels: false)
            imageButton(.releaseClipping, L10n.MenuImage.releaseClipping, pixels: false)
            Divider()
            Menu(L10n.MenuImage.newAdjustment) {
                adjustmentButton(.levels, L10n.Adjust.levels)
                adjustmentButton(.curves, L10n.Adjust.curves)
                adjustmentButton(.hueSaturation, L10n.Adjust.hueSaturation)
                adjustmentButton(.exposure, L10n.Adjust.exposure)
                adjustmentButton(.blackWhite, L10n.Adjust.blackWhite)
                adjustmentButton(.colorBalance, L10n.Adjust.colorBalance)
                adjustmentButton(.gradientMap, L10n.Adjust.gradientMap)
                adjustmentButton(.grain, L10n.Adjust.grain)
                adjustmentButton(.invert, L10n.Adjust.invert)
                adjustmentButton(.cameraRaw, L10n.Adjust.cameraRaw)
            }
            .disabled(actions == nil)
            Divider()
            effectButton(.stroke, L10n.Effect.stroke)
            effectButton(.shadow, L10n.Effect.dropShadow)
            effectButton(.colorOverlay, L10n.Effect.colorOverlay)
            effectButton(.innerShadow, L10n.Effect.innerShadow)
            effectButton(.outerGlow, L10n.Effect.outerGlow)
            effectButton(.innerGlow, L10n.Effect.innerGlow)
        }
    }

    private func imageButton(_ command: ImageCommand, _ title: String, pixels: Bool) -> some View {
        Button(title) { actions?.performImage(command) }
            .disabled(pixels ? actions?.canEditPixels != true : actions?.canMask != true)
    }

    private func adjustmentButton(_ kind: AdjustmentKind, _ title: String) -> some View {
        Button(title) { actions?.performImage(.newAdjustment(kind)) }
    }

    private func effectButton(_ kind: LayerEffectKind, _ title: String) -> some View {
        Button(title) { actions?.performImage(.toggleEffect(kind)) }
            .disabled(actions?.canEditPixels != true)
    }
}

@MainActor
private enum TextFieldKeys {
    static func send(_ selector: Selector) -> Bool {
        guard NSApp.keyWindow?.firstResponder is NSText else { return false }
        return NSApp.sendAction(selector, to: nil, from: nil)
    }
}
