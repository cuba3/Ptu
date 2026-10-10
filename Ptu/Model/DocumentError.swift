// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

enum DocumentError: Error, Equatable, LocalizedError {
    case unreadable
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .unreadable:
            L10n.Error.unreadable
        case .unsupportedVersion:
            L10n.Error.unsupportedVersion
        }
    }
}
