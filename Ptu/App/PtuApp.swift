// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

final class PtuAppDelegate: NSObject, NSApplicationDelegate {
    private var didPresentInitialDocument = false

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.presentInitialDocumentIfNeeded()
        }
    }

    private func presentInitialDocumentIfNeeded() {
        guard !didPresentInitialDocument else { return }
        didPresentInitialDocument = true
        let controller = NSDocumentController.shared
        if controller.documents.isEmpty {
            controller.newDocument(nil)
        }
        for window in NSApp.windows where window is NSOpenPanel {
            window.close()
        }
    }
}

@main
struct PtuApp: App {
    @NSApplicationDelegateAdaptor(PtuAppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: PtuDocument()) { configuration in
            EditorView(document: configuration.$document)
        }
        .commands { PtuCommands() }
        .defaultLaunchBehavior(.presented)
        .defaultSize(width: 1200, height: 760)

        Settings {
            SettingsView()
        }
    }
}
