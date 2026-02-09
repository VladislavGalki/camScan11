import UIKit

struct CapturedFrame: Equatable, Hashable {
    let id: UUID = UUID()
    var preview: UIImage? = nil
    /// База для фильтров (НЕ вращается)
    var previewBase: UIImage? = nil
    /// База для отображения (вращается)
    var displayBase: UIImage? = nil
    var original: UIImage? = nil
    var quad: Quadrilateral? = nil
    var drawingData: Data? = nil
    var drawingBase: UIImage? = nil
    var filterHistory: FilterHistory = FilterHistory(states: [FilterState()], currentIndex: 0)
    var isReady: Bool {
        preview != nil && original != nil
    }
}

extension CapturedFrame {
    var currentFilter: FilterState {
        filterHistory.current
    }

    mutating func applyFilter(_ state: FilterState) {
        filterHistory.push(state)
    }

    mutating func undoFilter() {
        filterHistory.undo()
    }

    mutating func redoFilter() {
        filterHistory.redo()
    }
}
