// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

struct DocumentHistory: Equatable, Sendable {
    static let limit = 50

    private(set) var undoStack: [DocumentModel] = []
    private(set) var redoStack: [DocumentModel] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func push(_ snapshot: DocumentModel) {
        undoStack.append(snapshot)
        if undoStack.count > Self.limit {
            undoStack.removeFirst(undoStack.count - Self.limit)
        }
        redoStack.removeAll()
    }

    mutating func undo(current: DocumentModel) -> DocumentModel? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        if redoStack.count > Self.limit {
            redoStack.removeFirst(redoStack.count - Self.limit)
        }
        return previous
    }

    mutating func redo(current: DocumentModel) -> DocumentModel? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }

    mutating func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
