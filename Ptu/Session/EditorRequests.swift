// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics

enum ZoomRequest: Equatable, Sendable {
    case zoomIn
    case zoomOut
    case actualSize
    case fit
}

enum Redraw: Equatable, Sendable {
    case none
    case full
    case rect(CGRect)
}
