// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import Foundation

struct CommandPaletteEntry: Identifiable {
    let id: String
    let title: String
    let shortcut: String?
    let isEnabled: Bool
    let perform: @MainActor () -> Void
}

enum CommandPaletteSearch {
    static func score(_ query: String, in text: String) -> Int? {
        let wanted = Array(query.lowercased().filter { !$0.isWhitespace })
        guard !wanted.isEmpty else { return 0 }
        let letters = Array(text.lowercased())
        var total = 0
        var from = 0
        var previous = -2
        for character in wanted {
            guard let found = letters[from...].firstIndex(of: character) else { return nil }
            let wordStart = found == 0 || !(letters[found - 1].isLetter || letters[found - 1].isNumber)
            total += 1 + (wordStart ? 8 : 0) + (found == previous + 1 ? 5 : 0)
            previous = found
            from = found + 1
        }
        let title = String(letters)
        let phrase = query.lowercased().trimmingCharacters(in: .whitespaces)
        let words = phrase.split(separator: " ").map(String.init)
        let tier: Int
        if wordsStartWords([phrase], in: title) {
            tier = 5
        } else if words.count > 1, wordsStartWords(words, in: title) {
            tier = 4
        } else if title.contains(phrase) {
            tier = 3
        } else if title.replacingOccurrences(of: " ", with: "").contains(String(wanted)) {
            tier = 2
        } else {
            tier = 1
        }
        return tier * 1_000_000 + (tier == 1 ? total * 100 : 0) - letters.count / 4
    }

    static func rank(_ entries: [CommandPaletteEntry], query: String) -> [CommandPaletteEntry] {
        let scored = entries.enumerated().compactMap { index, entry in
            score(query, in: entry.title).map { (entry, $0, index) }
        }
        return scored.sorted { lhs, rhs in
            if lhs.0.isEnabled != rhs.0.isEnabled { return lhs.0.isEnabled }
            if query.isEmpty || lhs.1 == rhs.1 { return lhs.2 < rhs.2 }
            return lhs.1 > rhs.1
        }.map(\.0)
    }

    private static func wordsStartWords(_ words: [String], in title: String) -> Bool {
        var from = title.startIndex
        for word in words {
            var found: String.Index?
            var search = from
            while let range = title.range(of: word, range: search..<title.endIndex) {
                if range.lowerBound == title.startIndex || !title[title.index(before: range.lowerBound)].isLetter {
                    found = range.upperBound
                    break
                }
                search = title.index(after: range.lowerBound)
            }
            guard let next = found else { return false }
            from = next
        }
        return true
    }
}

@MainActor
@Observable
final class CommandPaletteViewModel {
    let entries: [CommandPaletteEntry]
    var query = "" {
        didSet { if query != oldValue { selection = 0 } }
    }
    var selection = 0

    init(entries: [CommandPaletteEntry]) {
        self.entries = entries
    }

    var results: [CommandPaletteEntry] { CommandPaletteSearch.rank(entries, query: query) }

    var selected: CommandPaletteEntry? {
        let results = results
        return results.indices.contains(selection) ? results[selection] : nil
    }

    func move(by step: Int) {
        let count = results.count
        guard count > 0 else {
            selection = 0
            return
        }
        selection = ((selection + step) % count + count) % count
    }
}
