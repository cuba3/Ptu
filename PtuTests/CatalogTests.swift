// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import XCTest

final class CatalogTests: XCTestCase {
    func testEveryStringHasFourLocales() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ptu/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)
        XCTAssertEqual(catalog.sourceLanguage, "en")
        XCTAssertGreaterThanOrEqual(catalog.strings.count, 70)
        let required = ["en", "zh-Hans", "zh-Hant", "ja"]
        for (key, entry) in catalog.strings {
            let locales = entry.localizations ?? [:]
            for locale in required {
                let value = locales[locale]?.stringUnit?.value ?? ""
                XCTAssertFalse(value.isEmpty, "\(key) is missing \(locale)")
            }
        }
    }
}

private struct StringCatalog: Decodable {
    var sourceLanguage: String
    var strings: [String: CatalogEntry]
}

private struct CatalogEntry: Decodable {
    var localizations: [String: CatalogLocalization]?
}

private struct CatalogLocalization: Decodable {
    var stringUnit: CatalogStringUnit?
}

private struct CatalogStringUnit: Decodable {
    var value: String
}
