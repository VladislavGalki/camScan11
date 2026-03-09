import SwiftUI

struct FilesMenuOverlay: View {
    @Binding var isVisible: Bool

    let isLocked: Bool
    var canMoved: Bool = true
    let frame: CGRect

    let onSelect: (FilesMenuItem) -> Void
    let onClose: () -> Void

    var body: some View {
        if isVisible {
            LayoutMenuItemView(
                showGridMenu: $isVisible,
                isItemLocked: isLocked,
                canMoved: canMoved,
                menuFrame: frame,
                onSelectMenuItem: onSelect,
                onClose: onClose
            )
        }
    }
}
