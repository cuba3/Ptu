// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var language = AppLanguage.current

    func saveLanguage() {
        language.save()
    }
}
