// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

struct ToolSidebar: View {
    @Bindable var model: ToolsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                ForEach(EditorTool.allCases) { tool in
                    Button {
                        model.tool = tool
                    } label: {
                        Label(tool.title, systemImage: tool.symbolName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.tool == tool ? Color.accentColor : nil)
                    .controlSize(.large)
                }
                toolOptions
                Spacer(minLength: 0)
            }
            .padding(Theme.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.background)
    }

    @ViewBuilder
    private var toolOptions: some View {
        if model.tool.usesRoundCursor || model.tool == .marquee || model.tool == .lasso || model.tool == .wand || model.tool == .objectSelection || model.tool == .colorRange || model.tool == .type || model.tool == .shape || model.tool == .gradient || model.tool == .hand || model.tool == .zoom {
            Divider()
            Text(L10n.Tool.options)
                .font(.headline)
                .foregroundStyle(Theme.label)
        }
        if model.tool.usesRoundCursor {
            brushSlider(title: L10n.Brush.size, value: $model.brushSize, range: 1...256)
            brushSlider(title: L10n.Brush.hardness, value: $model.brushHardness, range: 0...1)
            brushSlider(title: L10n.Brush.opacity, value: $model.brushOpacity, range: 0...1)
        }
        switch model.tool {
        case .marquee:
            Picker(L10n.Shape.rectangle, selection: $model.marqueeShape) {
                Text(L10n.Selection.rectangle).tag(MarqueeShape.rectangle)
                Text(L10n.Selection.ellipse).tag(MarqueeShape.ellipse)
            }
            .pickerStyle(.segmented)
            Text(L10n.Selection.modifierHint).foregroundStyle(Theme.secondaryLabel)
            brushSlider(title: L10n.Selection.feather, value: $model.featherAmount, range: 0...64)
            Button(L10n.Selection.feather) { model.featherSelection() }
        case .lasso:
            Picker(L10n.Tool.lasso, selection: $model.lassoKind) {
                Text(L10n.Selection.freehand).tag(LassoKind.freehand)
                Text(L10n.Selection.polygonal).tag(LassoKind.polygonal)
            }
            .pickerStyle(.segmented)
            Text(L10n.Selection.modifierHint).foregroundStyle(Theme.secondaryLabel)
        case .wand:
            brushSlider(title: L10n.Selection.tolerance, value: $model.wandTolerance, range: 0...255)
            Toggle(L10n.Selection.contiguous, isOn: $model.wandContiguous)
            Toggle(L10n.Selection.sampleAllLayers, isOn: $model.sampleAllLayers)
        case .objectSelection:
            brushSlider(title: L10n.Selection.edgeOffset, value: $model.objectEdgeOffset, range: -10...10)
            Toggle(L10n.Selection.sampleAllLayers, isOn: $model.sampleAllLayers)
        case .colorRange:
            brushSlider(title: L10n.Selection.fuzziness, value: $model.colorFuzziness, range: 0...200)
            Toggle(L10n.Selection.sampleAllLayers, isOn: $model.sampleAllLayers)
            Text(L10n.Selection.modifierHint).foregroundStyle(Theme.secondaryLabel)
        case .clone:
            Toggle(L10n.Clone.aligned, isOn: $model.cloneAligned)
            Toggle(L10n.Selection.sampleAllLayers, isOn: $model.sampleAllLayers)
            Text(L10n.Clone.sourceHint).foregroundStyle(Theme.secondaryLabel)
        case .heal:
            Picker(L10n.Tool.heal, selection: $model.healMode) {
                Text(L10n.Heal.contentAware).tag(0)
                Text(L10n.Heal.texture).tag(1)
                Text(L10n.Heal.proximity).tag(2)
            }
        case .blur:
            brushSlider(title: L10n.BlurTool.radius, value: $model.blurRadius, range: 0.5...40)
        case .smudge:
            Picker(L10n.Tool.smudge, selection: $model.smudgeMode) {
                Text(L10n.Tool.smudge).tag(SmudgeMode.smudge)
                Text(L10n.SmudgeTool.liquify).tag(SmudgeMode.liquify)
            }
            .pickerStyle(.segmented)
        case .shape:
            Picker(L10n.Tool.shape, selection: $model.shapeKind) {
                Text(L10n.Shape.rectangle).tag(ShapeKind.rectangle)
                Text(L10n.Shape.ellipse).tag(ShapeKind.ellipse)
                Text(L10n.Shape.line).tag(ShapeKind.line)
            }
            if model.shapeKind == .rectangle {
                brushSlider(title: L10n.Shape.cornerRadius, value: $model.shapeCornerRadius, range: 0...200)
            }
            if model.shapeKind == .line {
                brushSlider(title: L10n.Shape.lineWidth, value: $model.shapeLineWidth, range: 1...64)
            }
        case .gradient:
            Picker(L10n.Tool.gradient, selection: $model.gradientKind) {
                Text(L10n.GradientTool.linear).tag(GradientKind.linear)
                Text(L10n.GradientTool.radial).tag(GradientKind.radial)
            }
            .pickerStyle(.segmented)
            Picker(L10n.GradientTool.toTransparent, selection: $model.gradientFade) {
                Text(L10n.GradientTool.toTransparent).tag(GradientFade.toTransparent)
                Text(L10n.GradientTool.toBackground).tag(GradientFade.toBackground)
            }
            Toggle(L10n.GradientTool.reversed, isOn: $model.gradientReversed)
        case .type:
            Text(L10n.TypeTool.placeHint).foregroundStyle(Theme.secondaryLabel)
            TypeTextField(model: model)
            brushSlider(title: L10n.TypeTool.fontSize, value: $model.typeFontSize, range: 8...256)
            Button(L10n.TypeTool.commit) { model.commitType() }
        case .hand:
            Text(L10n.Tool.handHint)
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        case .zoom:
            Text(L10n.Tool.zoomHint)
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        default:
            EmptyView()
        }
        if let message = model.toolMessage {
            Text(message)
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private struct TypeTextField: View {
        @Bindable var model: ToolsViewModel

        var body: some View {
            TypeTextInput(
                text: $model.typeText,
                isFocused: model.typeFieldFocused,
                focusNonce: model.typeFocusNonce,
                onFocus: { focused in
                    model.typeFieldFocused = focused
                    if focused { model.typeSession = true }
                    TextInsertionFocus.set("type-field", active: focused)
                },
                onSubmit: { model.commitType() },
                onCancel: { model.endTextEditing() }
            )
            .frame(minHeight: 24)
            .onDisappear { TextInsertionFocus.set("type-field", active: false) }
        }
    }

    private func brushSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: Theme.compactSpacing) {
            HStack {
                Text(title)
                Spacer(minLength: Theme.compactSpacing)
                Text(value.wrappedValue, format: .number.precision(.fractionLength(value.wrappedValue >= 2 ? 0 : 2)))
                    .foregroundStyle(Theme.secondaryLabel)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }
}

/// Single-line editor whose field editor is an NSTextView, so the system input method receives key events.
private struct TypeTextInput: NSViewRepresentable {
    @Binding var text: String
    var isFocused: Bool
    var focusNonce: Int
    var onFocus: (Bool) -> Void
    var onSubmit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onFocus: onFocus, onSubmit: onSubmit, onCancel: onCancel)
    }

    func makeNSView(context: Context) -> TypeField {
        let field = TypeField()
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.placeholderString = L10n.TypeTool.text
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.delegate = context.coordinator
        field.focusRingType = .default
        if let cell = field.cell as? NSTextFieldCell {
            cell.usesSingleLineMode = true
            cell.isScrollable = true
        }
        return field
    }

    func updateNSView(_ field: TypeField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onFocus = onFocus
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onCancel = onCancel
        if !field.hasComposition, field.stringValue != text {
            context.coordinator.pushing = true
            field.stringValue = text
            context.coordinator.pushing = false
        }
        if context.coordinator.lastNonce != focusNonce {
            context.coordinator.lastNonce = focusNonce
            field.applyFocus(true)
        } else if !isFocused {
            field.applyFocus(false)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onFocus: (Bool) -> Void
        var onSubmit: () -> Void
        var onCancel: () -> Void
        var pushing = false
        var lastNonce = 0

        init(text: Binding<String>, onFocus: @escaping (Bool) -> Void, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
            self.text = text
            self.onFocus = onFocus
            self.onSubmit = onSubmit
            self.onCancel = onCancel
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            onFocus(true)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            onFocus(false)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard !pushing, let field = notification.object as? NSTextField else { return }
            let value = field.stringValue
            if text.wrappedValue != value {
                text.wrappedValue = value
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onCancel()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit()
                return true
            }
            return false
        }
    }
}

private final class TypeField: NSTextField {
    var wantsFocus = false

    var hasComposition: Bool {
        (currentEditor() as? NSTextView)?.hasMarkedText() == true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyFocus(wantsFocus)
    }

    func applyFocus(_ focused: Bool) {
        wantsFocus = focused
        guard let window else { return }
        let editor = currentEditor()
        let responder = window.firstResponder
        let active = responder === self || (editor != nil && responder === editor)
        if focused, !active {
            window.makeFirstResponder(self)
        } else if !focused, active {
            let field = self
            DispatchQueue.main.async { [weak field] in
                guard let field, !field.wantsFocus, let window = field.window else { return }
                let editor = field.currentEditor()
                let responder = window.firstResponder
                if responder === field || (editor != nil && responder === editor) {
                    window.makeFirstResponder(nil)
                }
            }
        }
    }
}
