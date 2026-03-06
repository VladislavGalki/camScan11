import SwiftUI

struct FilesLayoutContainer: View {
    let mode: FilesViewMode
    let items: [FilesGridItem]
    let highlightedID: UUID?
    var shouldHideSettings: Bool = false

    let onFolderClick: ((UUID) -> Void)?
    let onDocumentClick: ((UUID) -> Void)?
    let onFavourite: (UUID, Bool) -> Void
    let onMenuClick: (UUID, CGRect) -> Void

    var body: some View {
        switch mode {
        case .grid:
            GridLayoutView(
                highlightedID: highlightedID,
                model: items,
                shouldHideSettings: shouldHideSettings,
                onFolderClick: onFolderClick,
                onDocumentClick: onDocumentClick,
                onFavouriteClick: onFavourite,
                onMenuClick: onMenuClick
            )
        case .list:
            ListLayoutView(
                highlightedID: highlightedID,
                model: items,
                shouldHideSettings: shouldHideSettings,
                onFolderClick: onFolderClick,
                onDocumentClick: onDocumentClick,
                onFavouriteClick: onFavourite,
                onMenuClick: onMenuClick
            )
        }
    }
}


