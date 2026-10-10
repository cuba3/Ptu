// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

struct NewCanvasSheet: View {
    @Bindable var model: NewCanvasViewModel
    var onCreate: (Int, Int, Double, CanvasBackground) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(L10n.Canvas.newTitle)
                .font(.title2)
            TextField(L10n.Canvas.width, value: $model.width, format: .number)
            TextField(L10n.Canvas.height, value: $model.height, format: .number)
            TextField(L10n.Canvas.resolution, value: $model.resolution, format: .number)
            Picker(L10n.Canvas.background, selection: $model.background) {
                ForEach(CanvasBackground.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            if model.showsError {
                Text(L10n.Canvas.invalidSize)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
            HStack {
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Text(L10n.Action.cancel)
                }
                .keyboardShortcut(.cancelAction)
                Button {
                    guard let canvas = model.validatedCanvas() else { return }
                    onCreate(canvas.width, canvas.height, canvas.resolutionPPI, canvas.background)
                } label: {
                    Text(L10n.Canvas.create)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("newCanvas.create")
            }
        }
        .padding(Theme.spacing * 1.5)
        .frame(minWidth: 360)
    }
}
