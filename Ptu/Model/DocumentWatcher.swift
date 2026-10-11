// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CryptoKit
import Foundation

enum PackageDigest {
    static func compute(for url: URL) -> Data? {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        var hasher = SHA256()
        if isDirectory.boolValue {
            let manifest = url.appendingPathComponent(ProjectStore.manifestName)
            guard let manifestData = try? Data(contentsOf: manifest) else { return nil }
            hasher.update(data: manifestData)
            let layers = url.appendingPathComponent(ProjectStore.layersDirectory, isDirectory: true)
            let files = (try? manager.contentsOfDirectory(at: layers, includingPropertiesForKeys: nil)) ?? []
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard let data = try? Data(contentsOf: file) else { return nil }
                hasher.update(data: Data(file.lastPathComponent.utf8))
                hasher.update(data: data)
            }
        } else {
            guard let data = try? Data(contentsOf: url) else { return nil }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return Data(digest)
    }
}

/// Watches a `.ptu` package (or a flat image) and reports one coalesced change.
@MainActor
final class DocumentWatcher {
    let url: URL
    private let onChange: @MainActor () -> Void
    private let sources = SourceBox()
    private var delivery: Task<Void, Never>?
    private var rearm: Task<Void, Never>?
    static let coalescing: Duration = .milliseconds(300)

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
        arm()
    }

    deinit { sources.cancelAll() }

    func stop() {
        delivery?.cancel()
        delivery = nil
        rearm?.cancel()
        rearm = nil
        sources.cancelAll()
    }

    private var watchedPaths: [String] {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return [
                url.path,
                url.appendingPathComponent(ProjectStore.manifestName).path,
                url.appendingPathComponent(ProjectStore.layersDirectory, isDirectory: true).path,
            ]
        }
        return [url.path]
    }

    private func arm() {
        sources.cancelAll()
        for path in watchedPaths {
            let descriptor = open(path, O_EVTONLY)
            guard descriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .delete, .rename, .link, .attrib],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.noteEvent() }
            }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            sources.append(source)
        }
    }

    private nonisolated final class SourceBox: @unchecked Sendable {
        private let lock = NSLock()
        private var list: [DispatchSourceFileSystemObject] = []
        var count: Int { lock.withLock { list.count } }
        func append(_ source: DispatchSourceFileSystemObject) { lock.withLock { list.append(source) } }
        func cancelAll() {
            let cancelled = lock.withLock { () -> [DispatchSourceFileSystemObject] in
                let current = list
                list.removeAll()
                return current
            }
            for source in cancelled { source.cancel() }
        }
    }

    private func noteEvent() {
        rearm?.cancel()
        rearm = Task { @MainActor [weak self] in
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { return }
                self.arm()
                if self.sources.count == self.watchedPaths.count { return }
            }
        }
        delivery?.cancel()
        delivery = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.coalescing)
            guard let self, !Task.isCancelled else { return }
            self.onChange()
        }
    }
}
