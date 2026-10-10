// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

/// User-visible strings. Keys are stable identifiers; English lives in `defaultValue`.
enum L10n {
    enum Tool {
        static var move: String {
            String(localized: "tool.move", defaultValue: "Move", comment: "Tool that moves the selected layer.")
        }
        static var marquee: String {
            String(localized: "tool.marquee", defaultValue: "Marquee", comment: "Rectangular selection tool.")
        }
        static var brush: String {
            String(localized: "tool.brush", defaultValue: "Brush", comment: "Painting tool.")
        }
        static var crop: String {
            String(localized: "tool.crop", defaultValue: "Crop", comment: "Canvas crop tool.")
        }
        static var eyedropper: String {
            String(localized: "tool.eyedropper", defaultValue: "Eyedropper", comment: "Tool that samples a color from the canvas.")
        }
        static var options: String {
            String(localized: "tool.options", defaultValue: "Tool Options", comment: "Heading above the controls for the current tool.")
        }
    }

    enum Brush {
        static var size: String {
            String(localized: "brush.size", defaultValue: "Size", comment: "Brush diameter.")
        }
        static var hardness: String {
            String(localized: "brush.hardness", defaultValue: "Hardness", comment: "Brush edge hardness.")
        }
        static var opacity: String {
            String(localized: "brush.opacity", defaultValue: "Opacity", comment: "Brush stroke opacity.")
        }
    }

    enum Menu {
        static var exportPNG: String {
            String(localized: "menu.file.exportPNG", defaultValue: "Export PNG…", comment: "File menu command that exports a flattened PNG.")
        }
        static var exportJPEG: String {
            String(localized: "menu.file.exportJPEG", defaultValue: "Export JPEG…", comment: "File menu command that exports a flattened JPEG.")
        }
    }

    enum Edit {
        static var undo: String {
            String(localized: "menu.edit.undo", defaultValue: "Undo", comment: "Undo the last edit.")
        }
        static var redo: String {
            String(localized: "menu.edit.redo", defaultValue: "Redo", comment: "Redo the last undone edit.")
        }
        static var deleteSelection: String {
            String(localized: "menu.edit.deleteSelection", defaultValue: "Delete Selection", comment: "Clears pixels inside the rectangular selection.")
        }
    }

    enum View {
        static var zoomIn: String {
            String(localized: "menu.view.zoomIn", defaultValue: "Zoom In", comment: "Magnify the canvas.")
        }
        static var zoomOut: String {
            String(localized: "menu.view.zoomOut", defaultValue: "Zoom Out", comment: "Shrink the canvas view.")
        }
        static var actualSize: String {
            String(localized: "menu.view.actualSize", defaultValue: "Actual Size", comment: "Show one document pixel per point.")
        }
        static var fit: String {
            String(localized: "menu.view.fit", defaultValue: "Fit Window", comment: "Scale the canvas so the whole document is visible.")
        }
    }

    enum Layer {
        static var section: String {
            String(localized: "layer.section", defaultValue: "Layers", comment: "Heading for the layer list.")
        }
        static var add: String {
            String(localized: "layer.add", defaultValue: "New Layer", comment: "Adds a transparent pixel layer.")
        }
        static var addGroup: String {
            String(localized: "layer.addGroup", defaultValue: "New Group", comment: "Adds an empty layer group.")
        }
        static var delete: String {
            String(localized: "layer.delete", defaultValue: "Delete Layer", comment: "Deletes the selected layer or group.")
        }
        static var duplicate: String {
            String(localized: "layer.duplicate", defaultValue: "Duplicate Layer", comment: "Duplicates the selected layer or group.")
        }
        static var bringForward: String {
            String(localized: "layer.bringForward", defaultValue: "Bring Forward", comment: "Moves the selected layer one step toward the front.")
        }
        static var sendBackward: String {
            String(localized: "layer.sendBackward", defaultValue: "Send Backward", comment: "Moves the selected layer one step toward the back.")
        }
        static var opacity: String {
            String(localized: "layer.opacity", defaultValue: "Opacity", comment: "Layer opacity.")
        }
        static var blend: String {
            String(localized: "layer.blend", defaultValue: "Blend Mode", comment: "Layer blend mode.")
        }
        static var name: String {
            String(localized: "layer.name", defaultValue: "Name", comment: "Layer name field.")
        }
        static var show: String {
            String(localized: "layer.visibility.show", defaultValue: "Show Layer", comment: "Makes a hidden layer visible.")
        }
        static var hide: String {
            String(localized: "layer.visibility.hide", defaultValue: "Hide Layer", comment: "Hides a visible layer.")
        }
        static var empty: String {
            String(localized: "layer.empty", defaultValue: "No Layers", comment: "Shown when the document has no layers.")
        }

        static func defaultName(_ number: Int) -> String {
            let format = String(
                localized: "layer.defaultName",
                defaultValue: "Layer %lld",
                comment: "Default name for a new pixel layer. The argument is a serial number."
            )
            return String(format: format, locale: .current, Int64(number))
        }

        static func defaultGroupName(_ number: Int) -> String {
            let format = String(
                localized: "layer.defaultGroupName",
                defaultValue: "Group %lld",
                comment: "Default name for a new layer group. The argument is a serial number."
            )
            return String(format: format, locale: .current, Int64(number))
        }

        static func copyName(_ name: String) -> String {
            let format = String(
                localized: "layer.copyName",
                defaultValue: "%@ Copy",
                comment: "Name of a duplicated layer. The argument is the original name."
            )
            return String(format: format, locale: .current, name)
        }
    }

    enum Blend {
        static var normal: String { String(localized: "blend.normal", defaultValue: "Normal", comment: "Normal blend mode.") }
        static var multiply: String { String(localized: "blend.multiply", defaultValue: "Multiply", comment: "Multiply blend mode.") }
        static var screen: String { String(localized: "blend.screen", defaultValue: "Screen", comment: "Screen blend mode.") }
        static var overlay: String { String(localized: "blend.overlay", defaultValue: "Overlay", comment: "Overlay blend mode.") }
        static var darken: String { String(localized: "blend.darken", defaultValue: "Darken", comment: "Darken blend mode.") }
        static var lighten: String { String(localized: "blend.lighten", defaultValue: "Lighten", comment: "Lighten blend mode.") }
        static var colorDodge: String { String(localized: "blend.colorDodge", defaultValue: "Color Dodge", comment: "Color Dodge blend mode.") }
        static var colorBurn: String { String(localized: "blend.colorBurn", defaultValue: "Color Burn", comment: "Color Burn blend mode.") }
        static var softLight: String { String(localized: "blend.softLight", defaultValue: "Soft Light", comment: "Soft Light blend mode.") }
        static var hardLight: String { String(localized: "blend.hardLight", defaultValue: "Hard Light", comment: "Hard Light blend mode.") }
        static var difference: String { String(localized: "blend.difference", defaultValue: "Difference", comment: "Difference blend mode.") }
        static var exclusion: String { String(localized: "blend.exclusion", defaultValue: "Exclusion", comment: "Exclusion blend mode.") }
    }

    enum Color {
        static var foreground: String {
            String(localized: "color.foreground", defaultValue: "Foreground", comment: "Foreground paint color.")
        }
        static var background: String {
            String(localized: "color.background", defaultValue: "Background", comment: "Background color chip.")
        }
        static var swap: String {
            String(localized: "color.swap", defaultValue: "Swap Colors", comment: "Exchanges the foreground and background colors.")
        }
        static var section: String {
            String(localized: "inspector.color", defaultValue: "Color", comment: "Heading for the color controls.")
        }
    }

    enum Canvas {
        static var newTitle: String {
            String(localized: "canvas.new.title", defaultValue: "New Canvas", comment: "Title of the new-canvas sheet.")
        }
        static var width: String {
            String(localized: "canvas.width", defaultValue: "Width", comment: "Canvas width field.")
        }
        static var height: String {
            String(localized: "canvas.height", defaultValue: "Height", comment: "Canvas height field.")
        }
        static var resolution: String {
            String(localized: "canvas.resolution", defaultValue: "Resolution", comment: "Canvas resolution field.")
        }
        static var background: String {
            String(localized: "canvas.background", defaultValue: "Background", comment: "New canvas background choice.")
        }
        static var backgroundTransparent: String {
            String(localized: "canvas.background.transparent", defaultValue: "Transparent", comment: "Transparent canvas background.")
        }
        static var backgroundWhite: String {
            String(localized: "canvas.background.white", defaultValue: "White", comment: "White canvas background.")
        }
        static var create: String {
            String(localized: "canvas.create", defaultValue: "Create", comment: "Confirms the new canvas sheet.")
        }
        static var invalidSize: String {
            String(localized: "canvas.sizeInvalid", defaultValue: "Enter a size between 1 and 16000.", comment: "Shown when the new canvas size is out of range.")
        }
    }

    enum Crop {
        static var apply: String {
            String(localized: "crop.apply", defaultValue: "Apply Crop", comment: "Applies the crop rectangle.")
        }
        static var cancel: String {
            String(localized: "crop.cancel", defaultValue: "Cancel Crop", comment: "Discards the crop rectangle.")
        }
    }

    enum Settings {
        static var language: String {
            String(localized: "settings.language", defaultValue: "Language", comment: "Settings label for the language picker.")
        }
        static var followSystem: String {
            String(localized: "settings.language.system", defaultValue: "Follow System", comment: "Use the system language.")
        }
        static var restart: String {
            String(localized: "settings.language.restart", defaultValue: "Quit and reopen Ptu to use the new language.", comment: "Explains that a language change applies on the next launch.")
        }
        static var english: String {
            String(localized: "settings.language.english", defaultValue: "English", comment: "Endonym for English.")
        }
        static var simplifiedChinese: String {
            String(localized: "settings.language.zhHans", defaultValue: "简体中文", comment: "Endonym for Simplified Chinese.")
        }
        static var traditionalChinese: String {
            String(localized: "settings.language.zhHant", defaultValue: "繁體中文", comment: "Endonym for Traditional Chinese.")
        }
        static var japanese: String {
            String(localized: "settings.language.japanese", defaultValue: "日本語", comment: "Endonym for Japanese.")
        }
    }

    enum Status {
        static func zoom(_ percent: Int) -> String {
            let format = String(
                localized: "status.zoom",
                defaultValue: "%lld%%",
                comment: "Zoom percentage in the toolbar. The argument is a whole number."
            )
            return String(format: format, locale: .current, Int64(percent))
        }
    }

    enum Inspector {
        static var document: String {
            String(localized: "inspector.document", defaultValue: "Document", comment: "Heading for document properties.")
        }
        static func size(width: Int, height: Int) -> String {
            let format = String(
                localized: "inspector.size",
                defaultValue: "%lld × %lld",
                comment: "Document size in pixels. Arguments are width and height."
            )
            return String(format: format, locale: .current, Int64(width), Int64(height))
        }
        static func resolution(_ ppi: Int) -> String {
            let format = String(
                localized: "inspector.resolution",
                defaultValue: "%lld px/in",
                comment: "Document resolution. The argument is pixels per inch."
            )
            return String(format: format, locale: .current, Int64(ppi))
        }
    }

    enum Error {
        static var unsupportedVersion: String {
            String(localized: "error.unsupportedVersion", defaultValue: "This document uses an unsupported format version.", comment: "Shown when a .ptu file version is not supported.")
        }
        static var unreadable: String {
            String(localized: "error.unreadable", defaultValue: "The file could not be read.", comment: "Shown when a file cannot be opened.")
        }
        static var exportFailed: String {
            String(localized: "error.exportFailed", defaultValue: "Export failed.", comment: "Shown when PNG or JPEG export fails.")
        }
    }

    enum Action {
        static var ok: String {
            String(localized: "action.ok", defaultValue: "OK", comment: "Dismisses an alert.")
        }
        static var cancel: String {
            String(localized: "action.cancel", defaultValue: "Cancel", comment: "Cancels a sheet.")
        }
    }

    enum Export {
        static var filename: String {
            String(localized: "export.filename", defaultValue: "Image", comment: "Default file name for a flattened export.")
        }
    }
}
