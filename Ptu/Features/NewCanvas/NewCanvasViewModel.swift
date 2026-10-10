// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation
import Observation

@MainActor
@Observable
final class NewCanvasViewModel {
    var width = 1920
    var height = 1080
    var resolution = 72
    var background: CanvasBackground = .transparent
    var showsError = false

    var isValid: Bool {
        (DocumentModel.minimumSide...DocumentModel.maximumSide).contains(width)
            && (DocumentModel.minimumSide...DocumentModel.maximumSide).contains(height)
            && (1...2400).contains(resolution)
    }

    func validatedCanvas() -> (width: Int, height: Int, resolutionPPI: Double, background: CanvasBackground)? {
        guard isValid else {
            showsError = true
            return nil
        }
        return (width, height, Double(resolution), background)
    }
}
