// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.Settings.followSystem
        case .english: L10n.Settings.english
        case .simplifiedChinese: L10n.Settings.simplifiedChinese
        case .traditionalChinese: L10n.Settings.traditionalChinese
        case .japanese: L10n.Settings.japanese
        }
    }

    static var current: AppLanguage {
        guard let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
              let first = languages.first else {
            return .system
        }
        return AppLanguage(rawValue: first) ?? .system
    }

    func save() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}
