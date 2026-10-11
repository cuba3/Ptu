// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Observation
import SwiftUI

struct PSDConversionRequest: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String
    var confirmTitle: String
    var notes: [PSDConversionNote]
    var isReading: Bool
    var allowsCancel: Bool
}

@MainActor
@Observable
final class PSDImportViewModel {
    var isChoosingFile = false
    var request: PSDConversionRequest?
    var errorMessage: String?
    private var pending: DocumentModel?
    var onApply: (DocumentModel) -> Void = { _ in }

    func presentReport(_ notes: [PSDConversionNote]) {
        guard !notes.isEmpty else { return }
        request = PSDConversionRequest(
            title: L10n.PSD.reportTitle,
            message: L10n.PSD.reportMessage,
            confirmTitle: L10n.Action.ok,
            notes: notes,
            isReading: false,
            allowsCancel: false
        )
    }

    func load(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        request = PSDConversionRequest(
            title: L10n.PSD.importTitle,
            message: L10n.PSD.reading,
            confirmTitle: L10n.PSD.continueImport,
            notes: [],
            isReading: true,
            allowsCancel: true
        )
        Task {
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try PSDImporter.read(url: url)
                }.value
                if result.notes.isEmpty {
                    request = nil
                    onApply(result.model)
                } else {
                    pending = result.model
                    request = PSDConversionRequest(
                        title: L10n.PSD.importTitle,
                        message: L10n.PSD.summary,
                        confirmTitle: L10n.PSD.continueImport,
                        notes: result.notes,
                        isReading: false,
                        allowsCancel: true
                    )
                }
            } catch {
                request = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    func confirm() {
        if let pending {
            onApply(pending)
        }
        pending = nil
        request = nil
    }

    func cancel() {
        pending = nil
        request = nil
    }
}
