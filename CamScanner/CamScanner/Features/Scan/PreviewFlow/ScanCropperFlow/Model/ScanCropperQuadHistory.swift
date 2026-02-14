import Foundation

struct ScanCropperQuadHistory: Equatable, Hashable {
    private(set) var states: [ScanCropperQuadState]
    private(set) var currentIndex: Int

    var current: ScanCropperQuadState {
        states[currentIndex]
    }

    init(initial: Quadrilateral) {
        self.states = [ScanCropperQuadState(quad: initial)]
        self.currentIndex = 0
    }
    
    var canUndo: Bool {
        currentIndex > 0
    }

    var canRedo: Bool {
        currentIndex < states.count - 1
    }

    mutating func push(_ newState: ScanCropperQuadState) {
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
