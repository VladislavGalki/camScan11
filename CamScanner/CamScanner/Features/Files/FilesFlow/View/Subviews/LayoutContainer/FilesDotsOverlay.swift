import SwiftUI

struct FilesDotsOverlay: View {
    @Binding var isVisible: Bool

    let frame: CGRect
    let sortType: FilesSortType
    let viewMode: FilesViewMode

    let onCreateFolder: () -> Void
    let onSelectFiles: () -> Void
    let onSort: (FilesSortType) -> Void
    let onViewMode: (FilesViewMode) -> Void
    let onDisappear: () -> Void

    var body: some View {
        if isVisible {
            DotsMenuView(
                isVisible: $isVisible,
                dotsFrame: frame,
                sortType: sortType,
                viewMode: viewMode,
                onCreateFolder: onCreateFolder,
                onSelectFiles: onSelectFiles,
                onSortChange: onSort,
                onViewModeChange: onViewMode
            )
            .onDisappear {
                onDisappear()
            }
        }
    }
}
