import SwiftUI

struct FilesLayoutContainer: View {
    let mode: FilesViewMode
    let items: [FilesGridItem]
    var highlightedID: UUID?
    var shouldHideAllSettings: Bool = false
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
                shouldHideAllSettings: shouldHideAllSettings,
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
                shouldHideAllSettings: shouldHideAllSettings,
                shouldHideSettings: shouldHideSettings,
                onFolderClick: onFolderClick,
                onDocumentClick: onDocumentClick,
                onFavouriteClick: onFavourite,
                onMenuClick: onMenuClick
            )
        }
    }
}


