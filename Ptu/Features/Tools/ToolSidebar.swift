// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct ToolSidebar: View {
    @Bindable var model: ToolsViewModel

    var body: some View {
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

            if model.tool == .brush {
                Divider()
                Text(L10n.Tool.options)
                    .font(.headline)
                    .foregroundStyle(Theme.label)
                brushSlider(title: L10n.Brush.size, value: $model.brushSize, range: 1...256)
                brushSlider(title: L10n.Brush.hardness, value: $model.brushHardness, range: 0...1)
                brushSlider(title: L10n.Brush.opacity, value: $model.brushOpacity, range: 0...1)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.spacing)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.background)
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
