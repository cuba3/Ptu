// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import CoreGraphics
import Foundation

let documentTabSpacing: CGFloat = 6

struct DocumentTabSlot: Identifiable, Equatable {
    let id: UUID
    let x: CGFloat
    let width: CGFloat
}

struct DocumentTabPillSlot: Equatable {
    let x: CGFloat
    let width: CGFloat
}

struct DocumentTabOverflow: Equatable {
    let visible: [DocumentTabSlot]
    let hiddenIDs: [UUID]
    let pill: DocumentTabPillSlot?
}

enum DocumentTabLayout {
    /// Drops the oldest tabs into an overflow pill until the rest fit. The selected tab stays visible.
    static func overflow(
        order: [UUID],
        widths: [UUID: CGFloat],
        selectedID: UUID,
        availableWidth: CGFloat,
        pillWidth: (Int) -> CGFloat
    ) -> DocumentTabOverflow {
        guard !order.isEmpty else { return DocumentTabOverflow(visible: [], hiddenIDs: [], pill: nil) }
        func span(_ ids: some Collection<UUID>) -> CGFloat {
            guard !ids.isEmpty else { return 0 }
            return ids.reduce(0) { $0 + (widths[$1] ?? 0) } + documentTabSpacing * CGFloat(ids.count - 1)
        }
        func place(_ ids: [UUID], startX: CGFloat) -> [DocumentTabSlot] {
            var x = startX
            return ids.map { id in
                let width = widths[id] ?? 0
                defer { x += width + documentTabSpacing }
                return DocumentTabSlot(id: id, x: x, width: width)
            }
        }
        if availableWidth <= 0 || span(order) <= availableWidth {
            return DocumentTabOverflow(visible: place(order, startX: 0), hiddenIDs: [], pill: nil)
        }
        var shown = order.count
        while shown > 1 {
            let hidden = order.count - shown
            let width = pillWidth(hidden) + documentTabSpacing + span(order.suffix(shown))
            if width <= availableWidth { break }
            shown -= 1
        }
        var visibleIDs = Array(order.suffix(shown))
        var hiddenIDs = Array(order.prefix(order.count - shown))
        if hiddenIDs.contains(selectedID), let bumped = visibleIDs.first {
            hiddenIDs.removeAll { $0 == selectedID }
            hiddenIDs.append(bumped)
            visibleIDs[0] = selectedID
            while visibleIDs.count > 1, pillWidth(hiddenIDs.count) + documentTabSpacing + span(visibleIDs) > availableWidth {
                hiddenIDs.append(visibleIDs.remove(at: 1))
            }
        }
        let pillW = pillWidth(hiddenIDs.count)
        let pill = DocumentTabPillSlot(x: 0, width: pillW)
        return DocumentTabOverflow(visible: place(visibleIDs, startX: pillW + documentTabSpacing), hiddenIDs: hiddenIDs, pill: pill)
    }
}
