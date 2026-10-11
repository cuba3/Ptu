// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct PSDConversionSheet: View {
    let request: PSDConversionRequest
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(request.title)
                .font(.title2.bold())
            Text(request.message)
                .foregroundStyle(Theme.secondaryLabel)
            if request.isReading {
                HStack(spacing: Theme.compactSpacing) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.PSD.reading)
                        .foregroundStyle(Theme.secondaryLabel)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else if request.notes.isEmpty {
                Text(L10n.PSD.noNotes)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            } else {
                List(request.notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.layerName)
                            .font(.headline)
                        Text(note.message)
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 180)
            }
            HStack {
                Spacer()
                if request.allowsCancel {
                    Button(L10n.Action.cancel, action: onCancel)
                        .keyboardShortcut(.cancelAction)
                }
                Button(request.confirmTitle, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(request.isReading)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
    }
}
