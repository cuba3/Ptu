// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let ptuDocument = UTType(exportedAs: "app.ptu.document", conformingTo: .package)
}

struct PtuDocument: FileDocument {
    var model: DocumentModel
    var prefersSetupSheet: Bool
    var loadToken: UUID

    static var readableContentTypes: [UTType] { [.ptuDocument, .png, .jpeg] }
    static var writableContentTypes: [UTType] { [.ptuDocument] }

    init() {
        model = DocumentModel.blank()
        prefersSetupSheet = true
        loadToken = UUID()
    }

    init(configuration: ReadConfiguration) throws {
        prefersSetupSheet = false
        loadToken = UUID()
        if configuration.contentType.conforms(to: .png) || configuration.contentType.conforms(to: .jpeg) {
            guard let data = configuration.file.regularFileContents else { throw DocumentError.unreadable }
            let decoded = try ImageFiles.decode(data)
            let filename = configuration.file.filename ?? configuration.file.preferredFilename
            let name = filename.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
                ?? L10n.Layer.defaultName(1)
            model = DocumentModel.imported(buffer: decoded.buffer, resolutionPPI: decoded.ppi, name: name)
        } else {
            model = try ProjectStore.read(wrapper: configuration.file)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try ProjectStore.write(model)
    }
}

struct ExportedImage: FileDocument {
    var data: Data

    static var readableContentTypes: [UTType] { [.png, .jpeg] }
    static var writableContentTypes: [UTType] { [.png, .jpeg] }

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
