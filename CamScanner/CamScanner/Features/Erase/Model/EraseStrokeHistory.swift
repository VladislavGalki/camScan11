import Foundation

struct EraseStrokeHistory: Equatable {
    private(set) var states: [[Stroke]]
    private(set) var currentIndex: Int

    var current: [Stroke] {
        states[currentIndex]
    }

    var canUndo: Bool {
        currentIndex > 0
    }

    var canRedo: Bool {
        currentIndex < states.count - 1
    }

    init() {
        self.states = [[]]
        self.currentIndex = 0
    }

    mutating func push(_ newStrokes: [Stroke]) {
        if currentIndex < states.count - 1 {
            states.removeSubrange((currentIndex + 1)...)
        }
        states.append(newStrokes)
        currentIndex = states.count - 1
    }

    mutating func undo() {
        guard canUndo else { return }
        currentIndex -= 1
    }

    mutating func redo() {
        guard canRedo else { return }
        currentIndex += 1
    }
}
