// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import Foundation

/// Most-recent-first file list. Opening a file moves it to the front and drops duplicates.
enum RecentFileList {
    static let limit = 10

    static func note(_ url: URL, into urls: [URL]) -> [URL] {
        let key = url.standardizedFileURL
        var next = urls.filter { $0.standardizedFileURL != key }
        next.insert(url, at: 0)
        if next.count > limit {
            next = Array(next.prefix(limit))
        }
        return next
    }

    static func removingMissing(_ urls: [URL], fileExists: (URL) -> Bool) -> [URL] {
        urls.filter(fileExists)
    }
}

@MainActor
final class RecentFiles: ObservableObject {
    static let shared = RecentFiles()

    @Published private(set) var urls: [URL] = []
    private var activation: NSObjectProtocol?

    private init() {
        activation = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in RecentFiles.shared.refresh() }
        }
    }

    func note(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        urls = RecentFileList.removingMissing(RecentFileList.note(url, into: urls)) { url in
            FileManager.default.fileExists(atPath: url.path)
        }
    }

    func clear() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        urls = []
    }

    func refresh() {
        let system = NSDocumentController.shared.recentDocumentURLs
        var merged: [URL] = []
        for url in system.reversed() {
            merged = RecentFileList.note(url, into: merged)
        }
        urls = RecentFileList.removingMissing(merged) { url in
            FileManager.default.fileExists(atPath: url.path)
        }
    }

    func open(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
    }
}
