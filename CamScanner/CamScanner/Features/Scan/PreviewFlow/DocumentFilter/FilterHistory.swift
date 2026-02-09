import Foundation

struct FilterHistory: Equatable, Hashable, Codable {
    private(set) var states: [FilterState]
    private(set) var currentIndex: Int

    var current: FilterState {
        states[currentIndex]
    }

    mutating func push(_ newState: FilterState) {
        if currentIndex < states.count - 1 {
            states.removeSubrange((currentIndex + 1)...)
        }

        states.append(newState)
        currentIndex = states.count - 1
    }

    mutating func undo() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    mutating func redo() {
        guard currentIndex < states.count - 1 else { return }
        currentIndex += 1
    }
}
