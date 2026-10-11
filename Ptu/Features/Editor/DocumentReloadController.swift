// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation
import Observation

@MainActor
@Observable
final class DocumentReloadController {
    var showPrompt = false
    private(set) var fileURL: URL?
    private var watcher: DocumentWatcher?
    private var knownDigest: Data?
    private var ignoredDigest: Data?
    private var pending: DocumentModel?
    private var pendingDigest: Data?
    private var checking = false
    private var queued = false
    var isEdited: () -> Bool = { false }
    var currentModel: () -> DocumentModel = { DocumentModel.blank() }
    var onReload: (DocumentModel) -> Void = { _ in }

    func watch(_ url: URL?) {
        if url == watcher?.url { return }
        stop()
        fileURL = url
        guard let url else { return }
        knownDigest = PackageDigest.compute(for: url)
        watcher = DocumentWatcher(url: url) { [weak self] in
            self?.schedule()
        }
    }

    func stop() {
        watcher?.stop()
        watcher = nil
    }

    func requestManual() {
        guard fileURL != nil else { return }
        knownDigest = nil
        ignoredDigest = nil
        schedule()
    }

    func keepMine() {
        ignoredDigest = pendingDigest
        pending = nil
        pendingDigest = nil
        showPrompt = false
    }

    func revert() {
        guard let pending else { return }
        onReload(pending)
        knownDigest = pendingDigest
        ignoredDigest = nil
        self.pending = nil
        pendingDigest = nil
        showPrompt = false
    }

    private func schedule() {
        queued = true
        guard !checking else { return }
        Task { await check() }
    }

    private func check() async {
        checking = true
        defer { checking = false }
        while queued {
            queued = false
            guard let url = fileURL else { return }
            let digest = await Task.detached(priority: .utility) {
                PackageDigest.compute(for: url)
            }.value
            guard let digest, digest != knownDigest, digest != ignoredDigest else { continue }
            let loaded = await Task.detached(priority: .utility) {
                Self.load(url)
            }.value
            guard let loaded else { continue }
            if loaded == currentModel() {
                knownDigest = digest
                continue
            }
            if isEdited() {
                pending = loaded
                pendingDigest = digest
                showPrompt = true
                return
            }
            onReload(loaded)
            knownDigest = digest
        }
    }

    nonisolated private static func load(_ url: URL) -> DocumentModel? {
        let ext = url.pathExtension.lowercased()
        if ext == "psd" || ext == "psb" {
            return try? PSDImporter.read(url: url).model
        }
        if ext == "png" || ext == "jpg" || ext == "jpeg" {
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? ImageFiles.decode(data) else { return nil }
            return DocumentModel.imported(
                buffer: decoded.buffer,
                resolutionPPI: decoded.ppi,
                name: url.deletingPathExtension().lastPathComponent
            )
        }
        guard let wrapper = try? FileWrapper(url: url, options: .immediate) else { return nil }
        return try? ProjectStore.read(wrapper: wrapper)
    }
}
