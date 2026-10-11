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
        static var lasso: String { String(localized: "tool.lasso", defaultValue: "Lasso", comment: "Freehand selection tool.") }
        static var wand: String { String(localized: "tool.wand", defaultValue: "Magic Wand", comment: "Selects similar colors.") }
        static var objectSelection: String { String(localized: "tool.objectSelection", defaultValue: "Object Selection", comment: "Selects the object under the pointer.") }
        static var colorRange: String { String(localized: "tool.colorRange", defaultValue: "Color Range", comment: "Selects a range of colors.") }
        static var clone: String { String(localized: "tool.clone", defaultValue: "Clone Stamp", comment: "Copies pixels from a source point.") }
        static var heal: String { String(localized: "tool.heal", defaultValue: "Spot Healing", comment: "Repairs a spot from surrounding pixels.") }
        static var blur: String { String(localized: "tool.blur", defaultValue: "Blur", comment: "Softens pixels under the brush.") }
        static var smudge: String { String(localized: "tool.smudge", defaultValue: "Smudge", comment: "Smears pixels under the brush.") }
        static var type: String { String(localized: "tool.type", defaultValue: "Type", comment: "Places text on a new layer.") }
        static var shape: String { String(localized: "tool.shape", defaultValue: "Shape", comment: "Draws a rectangle, ellipse, or line.") }
        static var gradient: String { String(localized: "tool.gradient", defaultValue: "Gradient", comment: "Paints a gradient on the active layer.") }
        static var hand: String { String(localized: "tool.hand", defaultValue: "Hand", comment: "Pans the canvas.") }
        static var zoom: String { String(localized: "tool.zoom", defaultValue: "Zoom", comment: "Zooms the canvas.") }
        static var handHint: String { String(localized: "tool.hand.hint", defaultValue: "Drag to pan. Hold Space with another tool.", comment: "Hand tool hint.") }
        static var zoomHint: String { String(localized: "tool.zoom.hint", defaultValue: "Click to zoom in. Option-click to zoom out. Drag a rectangle to zoom to it.", comment: "Zoom tool hint.") }
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
        static var importPSD: String {
            String(localized: "menu.file.importPSD", defaultValue: "Import Photoshop…", comment: "Imports a PSD or PSB file into the current document.")
        }
        static var reload: String {
            String(localized: "menu.file.reload", defaultValue: "Reload from Disk", comment: "Reloads the open document from its file.")
        }
        static var openRecent: String {
            String(localized: "menu.file.openRecent", defaultValue: "Open Recent", comment: "Submenu of recently opened files.")
        }
        static var clearRecent: String {
            String(localized: "menu.file.clearRecent", defaultValue: "Clear Menu", comment: "Clears the recent-files menu.")
        }
        static var noRecent: String {
            String(localized: "menu.file.noRecent", defaultValue: "No Recent Files", comment: "Shown when there are no recent files.")
        }
        static var open: String {
            String(localized: "menu.file.open", defaultValue: "Open…", comment: "Opens a document.")
        }
        static var commandPalette: String {
            String(localized: "menu.edit.commandPalette", defaultValue: "Command Palette", comment: "Opens the command palette.")
        }
        static var keyboardShortcuts: String {
            String(localized: "menu.edit.keyboardShortcuts", defaultValue: "Keyboard Shortcuts…", comment: "Opens the keyboard shortcut editor.")
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
        static var reset: String {
            String(localized: "color.reset", defaultValue: "Reset Colors", comment: "Sets the foreground to black and the background to white.")
        }
        static var hex: String {
            String(localized: "color.hex", defaultValue: "Hex", comment: "Hexadecimal color field.")
        }
        static var swatches: String {
            String(localized: "color.swatches", defaultValue: "Swatches", comment: "Heading for the color swatch palette.")
        }
        static var recent: String {
            String(localized: "color.recent", defaultValue: "Recent", comment: "Heading for recently used colors.")
        }
        static var noRecent: String {
            String(localized: "color.noRecent", defaultValue: "No recent colors", comment: "Shown when no colors have been picked yet.")
        }
        static var saturationField: String {
            String(localized: "color.saturation", defaultValue: "Saturation and Brightness", comment: "Accessibility label for the saturation field.")
        }
        static var hue: String {
            String(localized: "color.hue", defaultValue: "Hue", comment: "Accessibility label for the hue strip.")
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
        static var noSubject: String {
            String(localized: "error.noSubject", defaultValue: "No foreground subject was found.", comment: "Shown when subject detection finds nothing.")
        }
        static var fillNoSource: String {
            String(localized: "error.fillNoSource", defaultValue: "Not enough surrounding image to fill that selection.", comment: "Shown when content-aware fill has no donor pixels.")
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

    enum MenuImage {
        static var menu: String { String(localized: "menu.image", defaultValue: "Image", comment: "Image menu title.") }
        static var filter: String { String(localized: "menu.filter", defaultValue: "Filter", comment: "Filter menu title.") }
        static var layer: String { String(localized: "menu.layer", defaultValue: "Layer", comment: "Layer menu title.") }
        static var levels: String { String(localized: "menu.image.levels", defaultValue: "Levels…", comment: "Opens the Levels adjustment.") }
        static var curves: String { String(localized: "menu.image.curves", defaultValue: "Curves…", comment: "Opens the Curves adjustment.") }
        static var hueSaturation: String { String(localized: "menu.image.hueSaturation", defaultValue: "Hue/Saturation…", comment: "Opens Hue/Saturation.") }
        static var exposure: String { String(localized: "menu.image.exposure", defaultValue: "Exposure…", comment: "Opens the Exposure adjustment.") }
        static var blackWhite: String { String(localized: "menu.image.blackWhite", defaultValue: "Black & White…", comment: "Opens Black & White.") }
        static var colorBalance: String { String(localized: "menu.image.colorBalance", defaultValue: "Color Balance…", comment: "Opens Color Balance.") }
        static var gradientMap: String { String(localized: "menu.image.gradientMap", defaultValue: "Gradient Map…", comment: "Opens Gradient Map.") }
        static var grain: String { String(localized: "menu.image.grain", defaultValue: "Grain…", comment: "Opens the Grain adjustment.") }
        static var invert: String { String(localized: "menu.image.invert", defaultValue: "Invert", comment: "Inverts the selected layer.") }
        static var cameraRaw: String { String(localized: "menu.image.cameraRaw", defaultValue: "Camera Raw…", comment: "Opens the Camera Raw filter.") }
        static var developRaw: String { String(localized: "menu.image.developRaw", defaultValue: "Develop RAW…", comment: "Develops a camera RAW file into a document.") }
        static var gaussianBlur: String { String(localized: "menu.filter.gaussianBlur", defaultValue: "Gaussian Blur…", comment: "Opens Gaussian Blur.") }
        static var motionBlur: String { String(localized: "menu.filter.motionBlur", defaultValue: "Motion Blur…", comment: "Opens Motion Blur.") }
        static var addNoise: String { String(localized: "menu.filter.addNoise", defaultValue: "Add Noise…", comment: "Opens Add Noise.") }
        static var vignette: String { String(localized: "menu.filter.vignette", defaultValue: "Vignette…", comment: "Opens the Vignette filter.") }
        static var bloom: String { String(localized: "menu.filter.bloom", defaultValue: "Bloom…", comment: "Opens the Bloom filter.") }
        static var tonalContrast: String { String(localized: "menu.filter.tonalContrast", defaultValue: "Tonal Contrast…", comment: "Opens Tonal Contrast.") }
        static var dither: String { String(localized: "menu.filter.dither", defaultValue: "Dither…", comment: "Opens the Dither filter.") }
        static var lensCorrection: String { String(localized: "menu.filter.lensCorrection", defaultValue: "Lens Correction…", comment: "Opens Lens Correction.") }
        static var addMask: String { String(localized: "menu.layer.addMask", defaultValue: "Add Layer Mask", comment: "Adds a white layer mask.") }
        static var deleteMask: String { String(localized: "menu.layer.deleteMask", defaultValue: "Delete Layer Mask", comment: "Removes the layer mask.") }
        static var invertMask: String { String(localized: "menu.layer.invertMask", defaultValue: "Invert Layer Mask", comment: "Inverts mask coverage.") }
        static var enableMask: String { String(localized: "menu.layer.enableMask", defaultValue: "Enable Layer Mask", comment: "Enables the layer mask.") }
        static var disableMask: String { String(localized: "menu.layer.disableMask", defaultValue: "Disable Layer Mask", comment: "Disables the layer mask without deleting it.") }
        static var editMask: String { String(localized: "menu.layer.editMask", defaultValue: "Edit Mask", comment: "Paints the layer mask with the brush.") }
        static var clippingMask: String { String(localized: "menu.layer.clippingMask", defaultValue: "Create Clipping Mask", comment: "Clips the selected layer to the layer below.") }
        static var releaseClipping: String { String(localized: "menu.layer.releaseClipping", defaultValue: "Release Clipping Mask", comment: "Removes a live clipping mask.") }
        static var newAdjustment: String { String(localized: "menu.layer.newAdjustment", defaultValue: "New Adjustment Layer", comment: "Submenu for adjustment layers.") }
    }

    enum Adjust {
        static var apply: String { String(localized: "adjust.apply", defaultValue: "Apply", comment: "Applies an adjustment or filter.") }
        static var levels: String { String(localized: "adjust.levels", defaultValue: "Levels", comment: "Levels adjustment name.") }
        static var curves: String { String(localized: "adjust.curves", defaultValue: "Curves", comment: "Curves adjustment name.") }
        static var hueSaturation: String { String(localized: "adjust.hueSaturation", defaultValue: "Hue/Saturation", comment: "Hue/Saturation adjustment name.") }
        static var exposure: String { String(localized: "adjust.exposure", defaultValue: "Exposure", comment: "Exposure adjustment name.") }
        static var blackWhite: String { String(localized: "adjust.blackWhite", defaultValue: "Black & White", comment: "Black and white adjustment name.") }
        static var colorBalance: String { String(localized: "adjust.colorBalance", defaultValue: "Color Balance", comment: "Color Balance adjustment name.") }
        static var gradientMap: String { String(localized: "adjust.gradientMap", defaultValue: "Gradient Map", comment: "Gradient Map adjustment name.") }
        static var grain: String { String(localized: "adjust.grain", defaultValue: "Grain", comment: "Grain adjustment name.") }
        static var invert: String { String(localized: "adjust.invert", defaultValue: "Invert", comment: "Invert adjustment name.") }
        static var cameraRaw: String { String(localized: "adjust.cameraRaw", defaultValue: "Camera Raw", comment: "Camera Raw filter name.") }
        static var section: String { String(localized: "inspector.adjustments", defaultValue: "Adjustments", comment: "Inspector heading for adjustments.") }
        static var channel: String { String(localized: "adjust.channel", defaultValue: "Channel", comment: "Levels or curves channel.") }
        static var channelRGB: String { String(localized: "adjust.channel.rgb", defaultValue: "RGB", comment: "Composite channel.") }
        static var channelRed: String { String(localized: "adjust.channel.red", defaultValue: "Red", comment: "Red channel.") }
        static var channelGreen: String { String(localized: "adjust.channel.green", defaultValue: "Green", comment: "Green channel.") }
        static var channelBlue: String { String(localized: "adjust.channel.blue", defaultValue: "Blue", comment: "Blue channel.") }
        static var black: String { String(localized: "adjust.black", defaultValue: "Black", comment: "Input black point.") }
        static var white: String { String(localized: "adjust.white", defaultValue: "White", comment: "Input white point.") }
        static var gamma: String { String(localized: "adjust.gamma", defaultValue: "Gamma", comment: "Gamma correction.") }
        static var outputBlack: String { String(localized: "adjust.outputBlack", defaultValue: "Output Black", comment: "Output black point.") }
        static var outputWhite: String { String(localized: "adjust.outputWhite", defaultValue: "Output White", comment: "Output white point.") }
        static var hue: String { String(localized: "adjust.hue", defaultValue: "Hue", comment: "Hue shift.") }
        static var saturation: String { String(localized: "adjust.saturation", defaultValue: "Saturation", comment: "Saturation amount.") }
        static var lightness: String { String(localized: "adjust.lightness", defaultValue: "Lightness", comment: "Lightness amount.") }
        static var colorize: String { String(localized: "adjust.colorize", defaultValue: "Colorize", comment: "Colorize the image with one hue.") }
        static var offset: String { String(localized: "adjust.offset", defaultValue: "Offset", comment: "Exposure shadow offset.") }
        static var amount: String { String(localized: "adjust.amount", defaultValue: "Amount", comment: "Adjustment strength.") }
        static var size: String { String(localized: "adjust.size", defaultValue: "Size", comment: "Size of an effect or grain.") }
        static var roughness: String { String(localized: "adjust.roughness", defaultValue: "Roughness", comment: "Grain roughness.") }
        static var reversed: String { String(localized: "adjust.reversed", defaultValue: "Reverse", comment: "Reverses a gradient map.") }
        static var shadows: String { String(localized: "adjust.shadows", defaultValue: "Shadows", comment: "Shadow color or shadow tone.") }
        static var highlights: String { String(localized: "adjust.highlights", defaultValue: "Highlights", comment: "Highlight color or highlight tone.") }
        static var temperature: String { String(localized: "adjust.temperature", defaultValue: "Temperature", comment: "White balance temperature.") }
        static var tint: String { String(localized: "adjust.tint", defaultValue: "Tint", comment: "White balance tint.") }
        static var contrast: String { String(localized: "adjust.contrast", defaultValue: "Contrast", comment: "Contrast amount.") }
        static var whites: String { String(localized: "adjust.whites", defaultValue: "Whites", comment: "White point tone.") }
        static var blacks: String { String(localized: "adjust.blacks", defaultValue: "Blacks", comment: "Black point tone.") }
        static var vibrance: String { String(localized: "adjust.vibrance", defaultValue: "Vibrance", comment: "Vibrance amount.") }
        static var dehaze: String { String(localized: "adjust.dehaze", defaultValue: "Dehaze", comment: "Dehaze amount.") }
        static var sharpen: String { String(localized: "adjust.sharpen", defaultValue: "Sharpen", comment: "Sharpen amount.") }
        static var boost: String { String(localized: "adjust.boost", defaultValue: "Boost", comment: "RAW tone boost.") }
        static var reset: String { String(localized: "adjust.reset", defaultValue: "Reset", comment: "Restores as-shot RAW settings.") }
        static var preserveLuminosity: String { String(localized: "adjust.preserveLuminosity", defaultValue: "Preserve Luminosity", comment: "Keeps brightness while shifting color.") }
        static var cyanRed: String { String(localized: "adjust.cyanRed", defaultValue: "Cyan / Red", comment: "Color balance cyan-red axis.") }
        static var magentaGreen: String { String(localized: "adjust.magentaGreen", defaultValue: "Magenta / Green", comment: "Color balance magenta-green axis.") }
        static var yellowBlue: String { String(localized: "adjust.yellowBlue", defaultValue: "Yellow / Blue", comment: "Color balance yellow-blue axis.") }
        static var rangeMaster: String { String(localized: "adjust.range.master", defaultValue: "Master", comment: "Hue range that affects every color.") }
        static var rangeReds: String { String(localized: "adjust.range.reds", defaultValue: "Reds", comment: "Red hue range.") }
        static var rangeYellows: String { String(localized: "adjust.range.yellows", defaultValue: "Yellows", comment: "Yellow hue range.") }
        static var rangeGreens: String { String(localized: "adjust.range.greens", defaultValue: "Greens", comment: "Green hue range.") }
        static var rangeCyans: String { String(localized: "adjust.range.cyans", defaultValue: "Cyans", comment: "Cyan hue range.") }
        static var rangeBlues: String { String(localized: "adjust.range.blues", defaultValue: "Blues", comment: "Blue hue range.") }
        static var rangeMagentas: String { String(localized: "adjust.range.magentas", defaultValue: "Magentas", comment: "Magenta hue range.") }
        static var output: String { String(localized: "adjust.curves.output", defaultValue: "Output", comment: "Curves output for the white point.") }
        static var edit: String { String(localized: "adjust.edit", defaultValue: "Edit Adjustment", comment: "Opens the selected adjustment layer.") }
        static var feather: String { String(localized: "adjust.feather", defaultValue: "Feather", comment: "Vignette edge softness.") }
    }

    enum Filter {
        static var gaussianBlur: String { String(localized: "filter.gaussianBlur", defaultValue: "Gaussian Blur", comment: "Gaussian Blur filter name.") }
        static var motionBlur: String { String(localized: "filter.motionBlur", defaultValue: "Motion Blur", comment: "Motion Blur filter name.") }
        static var addNoise: String { String(localized: "filter.addNoise", defaultValue: "Add Noise", comment: "Add Noise filter name.") }
        static var vignette: String { String(localized: "filter.vignette", defaultValue: "Vignette", comment: "Vignette filter name.") }
        static var bloom: String { String(localized: "filter.bloom", defaultValue: "Bloom", comment: "Bloom filter name.") }
        static var tonalContrast: String { String(localized: "filter.tonalContrast", defaultValue: "Tonal Contrast", comment: "Tonal Contrast filter name.") }
        static var dither: String { String(localized: "filter.dither", defaultValue: "Dither", comment: "Dither filter name.") }
        static var lensCorrection: String { String(localized: "filter.lensCorrection", defaultValue: "Lens Correction", comment: "Lens Correction filter name.") }
        static var invert: String { String(localized: "filter.invert", defaultValue: "Invert", comment: "Invert filter name.") }
        static var radius: String { String(localized: "filter.radius", defaultValue: "Radius", comment: "Blur radius.") }
        static var angle: String { String(localized: "filter.angle", defaultValue: "Angle", comment: "Direction in degrees.") }
        static var distance: String { String(localized: "filter.distance", defaultValue: "Distance", comment: "Motion blur distance.") }
        static var monochromatic: String { String(localized: "filter.monochromatic", defaultValue: "Monochromatic", comment: "Noise that changes brightness only.") }
        static var gaussianNoise: String { String(localized: "filter.gaussianNoise", defaultValue: "Gaussian", comment: "Gaussian noise distribution.") }
        static var distortion: String { String(localized: "filter.distortion", defaultValue: "Distortion", comment: "Lens distortion amount.") }
    }

    enum Dither {
        static var style: String { String(localized: "dither.style", defaultValue: "Style", comment: "Dither style.") }
        static var levels: String { String(localized: "dither.levels", defaultValue: "Levels", comment: "Tones per channel.") }
        static var atkinson: String { String(localized: "dither.atkinson", defaultValue: "Atkinson", comment: "Atkinson dither.") }
        static var floyd: String { String(localized: "dither.floyd", defaultValue: "Floyd–Steinberg", comment: "Floyd-Steinberg dither.") }
        static var bayer2: String { String(localized: "dither.bayer2", defaultValue: "Bayer 2×2", comment: "Bayer 2 by 2 dither.") }
        static var bayer4: String { String(localized: "dither.bayer4", defaultValue: "Bayer 4×4", comment: "Bayer 4 by 4 dither.") }
        static var bayer8: String { String(localized: "dither.bayer8", defaultValue: "Bayer 8×8", comment: "Bayer 8 by 8 dither.") }
        static var dots: String { String(localized: "dither.dots", defaultValue: "Halftone Dots", comment: "Halftone dots.") }
        static var lines: String { String(localized: "dither.lines", defaultValue: "Halftone Lines", comment: "Halftone lines.") }
        static var diamonds: String { String(localized: "dither.diamonds", defaultValue: "Halftone Diamonds", comment: "Halftone diamonds.") }
        static var patterns: String { String(localized: "dither.patterns", defaultValue: "Patterns", comment: "Pattern dither.") }
        static var scanlines: String { String(localized: "dither.scanlines", defaultValue: "Scanlines", comment: "CRT scanlines.") }
        static var blackWhite: String { String(localized: "dither.blackWhite", defaultValue: "Black & White", comment: "Dither to black and white.") }
        static var twoColors: String { String(localized: "dither.twoColors", defaultValue: "Two Colors", comment: "Dither between two colors.") }
        static var original: String { String(localized: "dither.original", defaultValue: "Original", comment: "Dither while keeping the original colors.") }
    }

    enum Effect {
        static var section: String { String(localized: "inspector.effects", defaultValue: "Effects", comment: "Inspector heading for layer effects.") }
        static var stroke: String { String(localized: "effect.stroke", defaultValue: "Stroke", comment: "Stroke layer effect.") }
        static var dropShadow: String { String(localized: "effect.dropShadow", defaultValue: "Drop Shadow", comment: "Drop shadow layer effect.") }
        static var colorOverlay: String { String(localized: "effect.colorOverlay", defaultValue: "Color Overlay", comment: "Color overlay layer effect.") }
        static var innerShadow: String { String(localized: "effect.innerShadow", defaultValue: "Inner Shadow", comment: "Inner shadow layer effect.") }
        static var outerGlow: String { String(localized: "effect.outerGlow", defaultValue: "Outer Glow", comment: "Outer glow layer effect.") }
        static var innerGlow: String { String(localized: "effect.innerGlow", defaultValue: "Inner Glow", comment: "Inner glow layer effect.") }
    }

    enum Mask {
        static var section: String { String(localized: "inspector.mask", defaultValue: "Mask", comment: "Inspector heading for the layer mask.") }
        static var reveal: String { String(localized: "mask.reveal", defaultValue: "Reveal All", comment: "Fills the mask with white.") }
        static var hide: String { String(localized: "mask.hide", defaultValue: "Hide All", comment: "Fills the mask with black.") }
        static var paintHint: String { String(localized: "mask.paintHint", defaultValue: "The brush paints this mask. White reveals, black hides.", comment: "Explains mask painting.") }
    }

    enum PSD {
        static var importTitle: String { String(localized: "psd.import.title", defaultValue: "Import Photoshop", comment: "Title of the Photoshop import sheet.") }
        static var reportTitle: String { String(localized: "psd.import.reportTitle", defaultValue: "Photoshop Import", comment: "Title after a Photoshop file opens with conversion notes.") }
        static var summary: String { String(localized: "psd.import.summary", defaultValue: "These Photoshop features will change on import. Nothing is applied until you continue.", comment: "Explains that import waits for confirmation.") }
        static var reportMessage: String { String(localized: "psd.import.report", defaultValue: "This Photoshop file was imported with the following changes.", comment: "Shown when a Photoshop file was already opened.") }
        static var reading: String { String(localized: "psd.import.reading", defaultValue: "Reading the Photoshop file…", comment: "Progress text while a Photoshop file is read.") }
        static var continueImport: String { String(localized: "psd.import.continue", defaultValue: "Continue", comment: "Applies the Photoshop import.") }
        static var noNotes: String { String(localized: "psd.import.noNotes", defaultValue: "No special conversion is required.", comment: "Shown when a Photoshop file needs no conversion notes.") }
        static var truncated: String { String(localized: "psd.error.truncated", defaultValue: "The Photoshop file could not be read. It may be damaged or incomplete.", comment: "PSD read error.") }
        static var unsupportedVersion: String { String(localized: "psd.error.version", defaultValue: "This Photoshop file uses a format version Ptu can’t read.", comment: "PSD version error.") }
        static var unsupportedColorMode: String { String(localized: "psd.error.colorMode", defaultValue: "Only 8-bit RGB Photoshop files can be imported.", comment: "PSD color mode error.") }
        static var unsupportedDepth: String { String(localized: "psd.error.depth", defaultValue: "Only 8-bit RGB Photoshop files can be imported.", comment: "PSD bit depth error.") }
        static var unsupportedCompression: String { String(localized: "psd.error.compression", defaultValue: "This Photoshop file uses a layer compression method that isn’t supported.", comment: "PSD compression error.") }
        static var tooLarge: String { String(localized: "psd.error.tooLarge", defaultValue: "This Photoshop file is too large to import.", comment: "PSD size error.") }
        static var cropped: String { String(localized: "psd.note.cropped", defaultValue: "Pixels outside the canvas were not imported.", comment: "A layer was cropped to the canvas.") }
        static var text: String { String(localized: "psd.note.text", defaultValue: "Text was imported as pixels and can’t be edited.", comment: "Text layers are not kept as text.") }
        static var smartObject: String { String(localized: "psd.note.smartObject", defaultValue: "The smart object was rasterized.", comment: "Smart objects become pixels.") }
        static var effects: String { String(localized: "psd.note.effects", defaultValue: "Layer effects were discarded.", comment: "Layer effects are not imported.") }
        static var vector: String { String(localized: "psd.note.vector", defaultValue: "The vector shape was imported as pixels.", comment: "Vector layers become pixels.") }
        static var adjustment: String { String(localized: "psd.note.adjustment", defaultValue: "This adjustment isn’t supported and was skipped.", comment: "Adjustment layers are not imported.") }
        static var other: String { String(localized: "psd.note.other", defaultValue: "This Photoshop layer type isn’t supported and was imported as pixels.", comment: "Unsupported layer type.") }
        static var groupPass: String { String(localized: "psd.note.groupPass", defaultValue: "Folder pass-through isn’t supported. The group is blended as Normal.", comment: "Pass-through groups become normal.") }
        static var mask: String { String(localized: "psd.note.mask", defaultValue: "The layer mask was not imported.", comment: "Layer masks are dropped.") }
        static var clipping: String { String(localized: "psd.note.clipping", defaultValue: "Clipping was not imported.", comment: "Clipping masks are dropped.") }
        static var noPixels: String { String(localized: "psd.note.noPixels", defaultValue: "This layer had no pixels and was imported empty.", comment: "A layer without image data.") }
        static func unsupportedBlend(_ key: String) -> String {
            let format = String(localized: "psd.note.blend", defaultValue: "Blend mode “%@” isn’t supported and was imported as Normal.", comment: "The argument is the Photoshop blend key.")
            return String(format: format, locale: .current, key)
        }
    }

    enum JPEG {
        static var title: String { String(localized: "jpeg.title", defaultValue: "Export JPEG", comment: "Title of the JPEG quality sheet.") }
        static var quality: String { String(localized: "jpeg.quality", defaultValue: "Quality", comment: "JPEG quality slider.") }
        static var export: String { String(localized: "jpeg.export", defaultValue: "Export…", comment: "Confirms JPEG export and opens the save panel.") }
        static var updating: String { String(localized: "jpeg.updating", defaultValue: "Updating…", comment: "Shown while a JPEG preview is encoded.") }
        static var matte: String { String(localized: "jpeg.matte", defaultValue: "Transparent areas are filled with white.", comment: "JPEG has no transparency.") }
    }

    enum Tabs {
        static var new: String { String(localized: "tabs.new", defaultValue: "New Tab", comment: "Opens a new document tab.") }
        static var close: String { String(localized: "tabs.close", defaultValue: "Close Tab", comment: "Closes a document tab.") }
        static var untitled: String { String(localized: "tabs.untitled", defaultValue: "Untitled", comment: "Title of a document that has not been saved.") }
        static func overflow(_ count: Int) -> String {
            let format = String(localized: "tabs.overflow", defaultValue: "%lld more", comment: "Overflow menu for document tabs. The argument is how many tabs are hidden.")
            return String(format: format, locale: .current, Int64(count))
        }
    }

    enum Reload {
        static var title: String { String(localized: "reload.title", defaultValue: "This document was changed on disk.", comment: "Alert title when the open file changes.") }
        static var message: String { String(localized: "reload.message", defaultValue: "You can reload the version on disk, or keep the open version.", comment: "Alert body when the open file changes.") }
        static var revert: String { String(localized: "reload.revert", defaultValue: "Reload", comment: "Replaces the open document with the file on disk.") }
        static var keep: String { String(localized: "reload.keep", defaultValue: "Keep Mine", comment: "Keeps the open document and ignores the file on disk.") }
    }

    enum Command {
        static var placeholder: String { String(localized: "command.placeholder", defaultValue: "Search commands", comment: "Command palette search field.") }
        static var empty: String { String(localized: "command.empty", defaultValue: "No matching commands", comment: "Shown when the command palette has no matches.") }
        static func openRecent(_ name: String) -> String {
            let format = String(localized: "command.openRecent", defaultValue: "Open Recent › %@", comment: "Command palette entry for a recent file. The argument is the file name.")
            return String(format: format, locale: .current, name)
        }
    }

    enum Shortcuts {
        static var title: String { String(localized: "shortcuts.title", defaultValue: "Keyboard Shortcuts", comment: "Title of the shortcut editor.") }
        static var hint: String { String(localized: "shortcuts.hint", defaultValue: "Click a shortcut, then press the new keys.", comment: "How to change a shortcut.") }
        static var recording: String { String(localized: "shortcuts.recording", defaultValue: "Press a shortcut. Esc cancels.", comment: "Shown while a shortcut is being recorded.") }
        static var reset: String { String(localized: "shortcuts.reset", defaultValue: "Reset", comment: "Restores the default shortcuts.") }
        static var save: String { String(localized: "shortcuts.save", defaultValue: "Save", comment: "Saves shortcut changes.") }
        static var groupMenu: String { String(localized: "shortcuts.group.menu", defaultValue: "Menus", comment: "Shortcut group for menu commands.") }
        static var groupCanvas: String { String(localized: "shortcuts.group.canvas", defaultValue: "Canvas", comment: "Shortcut group for canvas and layer commands.") }
        static var deleteKey: String { String(localized: "shortcuts.key.delete", defaultValue: "Delete", comment: "Name of the Delete key.") }
        static var returnKey: String { String(localized: "shortcuts.key.return", defaultValue: "Return", comment: "Name of the Return key.") }
        static var escapeKey: String { String(localized: "shortcuts.key.escape", defaultValue: "Esc", comment: "Name of the Escape key.") }
        static var tabKey: String { String(localized: "shortcuts.key.tab", defaultValue: "Tab", comment: "Name of the Tab key.") }
        static var spaceKey: String { String(localized: "shortcuts.key.space", defaultValue: "Space", comment: "Name of the Space key.") }
        static var singleKey: String { String(localized: "shortcuts.singleKey", defaultValue: "Choose a single key with optional modifiers.", comment: "Shortcut validation error.") }
        static var needsModifier: String { String(localized: "shortcuts.needsModifier", defaultValue: "Menu shortcuts need Command or Control.", comment: "Menu shortcuts must include a modifier.") }
        static func reserved(_ label: String) -> String {
            let format = String(localized: "shortcuts.reserved", defaultValue: "%@ is reserved by macOS.", comment: "The argument is a shortcut label.")
            return String(format: format, locale: .current, label)
        }
        static func duplicate(_ label: String, _ first: String, _ second: String) -> String {
            let format = String(localized: "shortcuts.duplicate", defaultValue: "%1$@ is assigned to both %2$@ and %3$@.", comment: "Two commands share a shortcut. Arguments are the shortcut, then the two command names.")
            return String(format: format, locale: .current, label, first, second)
        }
    }

    enum Selection {
        static var freehand: String { String(localized: "selection.freehand", defaultValue: "Freehand", comment: "Freehand lasso.") }
        static var polygonal: String { String(localized: "selection.polygonal", defaultValue: "Polygonal", comment: "Polygonal lasso.") }
        static var rectangle: String { String(localized: "selection.rectangle", defaultValue: "Rectangle", comment: "Rectangular marquee shape.") }
        static var ellipse: String { String(localized: "selection.ellipse", defaultValue: "Ellipse", comment: "Elliptical marquee shape.") }
        static var tolerance: String { String(localized: "selection.tolerance", defaultValue: "Tolerance", comment: "Magic wand color tolerance.") }
        static var contiguous: String { String(localized: "selection.contiguous", defaultValue: "Contiguous", comment: "Magic wand selects only connected pixels.") }
        static var fuzziness: String { String(localized: "selection.fuzziness", defaultValue: "Fuzziness", comment: "Color range fuzziness.") }
        static var feather: String { String(localized: "selection.feather", defaultValue: "Feather", comment: "Softens the selection edge.") }
        static var sampleAllLayers: String { String(localized: "selection.sampleAllLayers", defaultValue: "Sample All Layers", comment: "Sample the composite instead of the active layer.") }
        static var edgeOffset: String { String(localized: "selection.edgeOffset", defaultValue: "Edge Offset", comment: "Grows or shrinks an object selection.") }
        static var modifierHint: String { String(localized: "selection.modifierHint", defaultValue: "Shift adds. Option subtracts.", comment: "How modifiers change a selection.") }
        static var noMatch: String { String(localized: "selection.noMatch", defaultValue: "Nothing matched.", comment: "Shown when a selection click matches no pixels.") }
        static var menu: String { String(localized: "menu.select", defaultValue: "Select", comment: "Select menu title.") }
        static var all: String { String(localized: "menu.select.all", defaultValue: "Select All", comment: "Selects the whole canvas.") }
        static var deselect: String { String(localized: "menu.select.deselect", defaultValue: "Deselect", comment: "Clears the selection.") }
        static var inverse: String { String(localized: "menu.select.inverse", defaultValue: "Inverse", comment: "Inverts the selection.") }
        static var copy: String { String(localized: "menu.select.copy", defaultValue: "Copy", comment: "Copies the selected pixels.") }
        static var cut: String { String(localized: "menu.select.cut", defaultValue: "Cut", comment: "Cuts the selected pixels.") }
        static var paste: String { String(localized: "menu.select.paste", defaultValue: "Paste", comment: "Pastes copied pixels as a new layer.") }
        static var floatSelection: String { String(localized: "menu.select.float", defaultValue: "Float Selection", comment: "Lifts the selected pixels so they can be moved.") }
        static var contentFill: String { String(localized: "menu.select.contentFill", defaultValue: "Content-Aware Fill", comment: "Fills the selection from surrounding pixels.") }
        static var subject: String { String(localized: "menu.select.subject", defaultValue: "Select Subject", comment: "Selects the foreground subject.") }
        static var removeBackground: String { String(localized: "menu.select.removeBackground", defaultValue: "Remove Background", comment: "Clears pixels outside the detected subject.") }
    }

    enum Clone {
        static var aligned: String { String(localized: "clone.aligned", defaultValue: "Aligned", comment: "Clone stamp keeps one source offset.") }
        static var sourceHint: String { String(localized: "clone.sourceHint", defaultValue: "Option-click to set the source.", comment: "How to choose the clone stamp source.") }
    }

    enum Heal {
        static var contentAware: String { String(localized: "heal.contentAware", defaultValue: "Content-Aware", comment: "Spot healing matches nearby texture.") }
        static var texture: String { String(localized: "heal.texture", defaultValue: "Create Texture", comment: "Spot healing synthesizes texture.") }
        static var proximity: String { String(localized: "heal.proximity", defaultValue: "Proximity Match", comment: "Spot healing copies the nearest patch.") }
    }

    enum BlurTool {
        static var radius: String { String(localized: "blur.radius", defaultValue: "Radius", comment: "Blur tool radius.") }
    }

    enum SmudgeTool {
        static var liquify: String { String(localized: "smudge.liquify", defaultValue: "Liquify", comment: "Pushes pixels along the stroke.") }
    }

    enum Shape {
        static var rectangle: String { String(localized: "shape.rectangle", defaultValue: "Rectangle", comment: "Rectangle shape.") }
        static var ellipse: String { String(localized: "shape.ellipse", defaultValue: "Ellipse", comment: "Ellipse shape.") }
        static var line: String { String(localized: "shape.line", defaultValue: "Line", comment: "Line shape.") }
        static var cornerRadius: String { String(localized: "shape.cornerRadius", defaultValue: "Corner Radius", comment: "Rounded rectangle corner radius.") }
        static var lineWidth: String { String(localized: "shape.lineWidth", defaultValue: "Line Width", comment: "Line thickness.") }
        static func layerName(_ title: String, _ number: Int) -> String {
            let format = String(localized: "shape.layerName", defaultValue: "%@ %lld", comment: "Name of a new shape layer. Arguments are the shape name and a serial number.")
            return String(format: format, locale: .current, title, Int64(number))
        }
    }

    enum GradientTool {
        static var linear: String { String(localized: "gradient.linear", defaultValue: "Linear", comment: "Linear gradient.") }
        static var radial: String { String(localized: "gradient.radial", defaultValue: "Radial", comment: "Radial gradient.") }
        static var toBackground: String { String(localized: "gradient.toBackground", defaultValue: "Foreground to Background", comment: "Gradient from the foreground color to the background color.") }
        static var toTransparent: String { String(localized: "gradient.toTransparent", defaultValue: "Foreground to Transparent", comment: "Gradient from the foreground color to transparent.") }
        static var reversed: String { String(localized: "gradient.reversed", defaultValue: "Reversed", comment: "Swaps the gradient colors.") }
    }

    enum TypeTool {
        static var text: String { String(localized: "type.text", defaultValue: "Text", comment: "Type tool text field.") }
        static var fontSize: String { String(localized: "type.fontSize", defaultValue: "Font Size", comment: "Type tool font size.") }
        static var commit: String { String(localized: "type.commit", defaultValue: "Place Text", comment: "Rasterizes the text onto a new layer.") }
        static var placeHint: String { String(localized: "type.placeHint", defaultValue: "Click the canvas to place text.", comment: "Shown before the type tool has an origin.") }
    }

    enum Geometry {
        static var transform: String { String(localized: "geometry.transform", defaultValue: "Transform", comment: "Menu of transform, flip, resize, and trim commands.") }
        static var freeTransform: String { String(localized: "geometry.freeTransform", defaultValue: "Free Transform", comment: "Scales, rotates, and moves the selected layer.") }
        static var distort: String { String(localized: "geometry.distort", defaultValue: "Distort", comment: "Moves the selected layer's corners independently.") }
        static var apply: String { String(localized: "geometry.apply", defaultValue: "Apply Transform", comment: "Bakes the transform into the layer pixels.") }
        static var cancel: String { String(localized: "geometry.cancel", defaultValue: "Cancel Transform", comment: "Discards the transform preview.") }
        static var flipHorizontal: String { String(localized: "geometry.flipHorizontal", defaultValue: "Flip Horizontal", comment: "Flips the selected layer left to right.") }
        static var flipVertical: String { String(localized: "geometry.flipVertical", defaultValue: "Flip Vertical", comment: "Flips the selected layer top to bottom.") }
        static var flipCanvasHorizontal: String { String(localized: "geometry.flipCanvasHorizontal", defaultValue: "Flip Canvas Horizontal", comment: "Mirrors the whole canvas left to right.") }
        static var flipCanvasVertical: String { String(localized: "geometry.flipCanvasVertical", defaultValue: "Flip Canvas Vertical", comment: "Mirrors the whole canvas top to bottom.") }
        static var rotateClockwise: String { String(localized: "geometry.rotateClockwise", defaultValue: "Rotate 90° Clockwise", comment: "Turns the canvas a quarter turn clockwise.") }
        static var rotateCounterclockwise: String { String(localized: "geometry.rotateCounterclockwise", defaultValue: "Rotate 90° Counterclockwise", comment: "Turns the canvas a quarter turn counterclockwise.") }
        static var rotate180: String { String(localized: "geometry.rotate180", defaultValue: "Rotate 180°", comment: "Turns the canvas halfway around.") }
        static var imageSize: String { String(localized: "geometry.imageSize", defaultValue: "Image Size…", comment: "Resamples the document and its layers.") }
        static var canvasSize: String { String(localized: "geometry.canvasSize", defaultValue: "Canvas Size…", comment: "Changes the canvas bounds without resampling.") }
        static var trim: String { String(localized: "geometry.trim", defaultValue: "Trim…", comment: "Crops away empty edges.") }
        static var rulers: String { String(localized: "geometry.rulers", defaultValue: "Rulers", comment: "Shows or hides the canvas rulers.") }
        static var guides: String { String(localized: "geometry.guides", defaultValue: "Guides", comment: "Shows or hides alignment guides.") }
        static var grid: String { String(localized: "geometry.grid", defaultValue: "Grid", comment: "Shows or hides the layout grid.") }
        static var gridSettings: String { String(localized: "geometry.gridSettings", defaultValue: "Grid Settings…", comment: "Opens the grid spacing sheet.") }
        static var snap: String { String(localized: "geometry.snap", defaultValue: "Snap", comment: "Toggles snapping guides to the grid and canvas.") }
        static var clearGuides: String { String(localized: "geometry.clearGuides", defaultValue: "Clear Guides", comment: "Removes every guide.") }
        static var addHorizontalGuide: String { String(localized: "geometry.addHorizontalGuide", defaultValue: "Add Horizontal Guide", comment: "Adds a horizontal guide through the canvas center.") }
        static var addVerticalGuide: String { String(localized: "geometry.addVerticalGuide", defaultValue: "Add Vertical Guide", comment: "Adds a vertical guide through the canvas center.") }
        static var hand: String { String(localized: "geometry.hand", defaultValue: "Hand Tool", comment: "Chooses the hand tool.") }
        static var zoomTool: String { String(localized: "geometry.zoomTool", defaultValue: "Zoom Tool", comment: "Chooses the zoom tool.") }
        static var anchor: String { String(localized: "geometry.anchor", defaultValue: "Anchor", comment: "Which edge stays put when the canvas size changes.") }
        static var lockAspect: String { String(localized: "geometry.lockAspect", defaultValue: "Lock Aspect Ratio", comment: "Keeps width and height proportional.") }
        static var resample: String { String(localized: "geometry.resample", defaultValue: "Resample", comment: "How pixels are scaled.") }
    }

    enum Sampling {
        static var nearest: String { String(localized: "sampling.nearest", defaultValue: "Nearest Neighbor", comment: "Scales by copying the nearest pixel.") }
        static var smooth: String { String(localized: "sampling.smooth", defaultValue: "Smooth", comment: "Scales with a soft filter.") }
        static var high: String { String(localized: "sampling.high", defaultValue: "High Quality", comment: "Scales with a high-quality filter.") }
    }

    enum Trim {
        static var title: String { String(localized: "trim.title", defaultValue: "Trim", comment: "Title of the trim sheet.") }
        static var basedOn: String { String(localized: "trim.basedOn", defaultValue: "Based On", comment: "What counts as an empty edge.") }
        static var transparent: String { String(localized: "trim.transparent", defaultValue: "Transparent Pixels", comment: "Trims fully transparent pixels.") }
        static var topLeft: String { String(localized: "trim.topLeft", defaultValue: "Top Left Pixel Color", comment: "Trims pixels matching the top-left color.") }
        static var bottomRight: String { String(localized: "trim.bottomRight", defaultValue: "Bottom Right Pixel Color", comment: "Trims pixels matching the bottom-right color.") }
        static var top: String { String(localized: "trim.top", defaultValue: "Top", comment: "Trims the top edge.") }
        static var bottom: String { String(localized: "trim.bottom", defaultValue: "Bottom", comment: "Trims the bottom edge.") }
        static var left: String { String(localized: "trim.left", defaultValue: "Left", comment: "Trims the left edge.") }
        static var right: String { String(localized: "trim.right", defaultValue: "Right", comment: "Trims the right edge.") }
        static var tolerance: String { String(localized: "trim.tolerance", defaultValue: "Tolerance", comment: "How far a pixel may differ and still be trimmed.") }
        static var empty: String { String(localized: "trim.empty", defaultValue: "Nothing to trim.", comment: "Shown when trim would not change the canvas.") }
    }

    enum GridSettings {
        static var title: String { String(localized: "grid.title", defaultValue: "Grid Settings", comment: "Title of the grid settings sheet.") }
        static var spacing: String { String(localized: "grid.spacing", defaultValue: "Gridline Every", comment: "Pixels between major grid lines.") }
        static var subdivisions: String { String(localized: "grid.subdivisions", defaultValue: "Subdivisions", comment: "How many parts each grid square is split into.") }
    }

    enum Anchor {
        static var topLeft: String { String(localized: "anchor.topLeft", defaultValue: "Top Left", comment: "Canvas anchor at the top left.") }
        static var top: String { String(localized: "anchor.top", defaultValue: "Top", comment: "Canvas anchor at the top center.") }
        static var topRight: String { String(localized: "anchor.topRight", defaultValue: "Top Right", comment: "Canvas anchor at the top right.") }
        static var left: String { String(localized: "anchor.left", defaultValue: "Left", comment: "Canvas anchor at the left center.") }
        static var center: String { String(localized: "anchor.center", defaultValue: "Center", comment: "Canvas anchor at the center.") }
        static var right: String { String(localized: "anchor.right", defaultValue: "Right", comment: "Canvas anchor at the right center.") }
        static var bottomLeft: String { String(localized: "anchor.bottomLeft", defaultValue: "Bottom Left", comment: "Canvas anchor at the bottom left.") }
        static var bottom: String { String(localized: "anchor.bottom", defaultValue: "Bottom", comment: "Canvas anchor at the bottom center.") }
        static var bottomRight: String { String(localized: "anchor.bottomRight", defaultValue: "Bottom Right", comment: "Canvas anchor at the bottom right.") }
    }
}
