// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

/// Semantic colors and spacing. The window follows the system appearance.
enum Theme {
    static let spacing: CGFloat = 12
    static let compactSpacing: CGFloat = 8
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 240
    static let inspectorMinWidth: CGFloat = 240
    static let inspectorIdealWidth: CGFloat = 280

    static var windowBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var canvasBackdrop: Color { Color(nsColor: .underPageBackgroundColor) }
    static var label: Color { Color(nsColor: .labelColor) }
    static var secondaryLabel: Color { Color(nsColor: .secondaryLabelColor) }
}
