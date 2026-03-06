import SwiftUI

struct LayoutMenuFolderView: View {
    @Binding var showGridMenu: Bool

    let isItemLocked: Bool
    let menuFrame: CGRect
    let onSelectMenuItem: (FilesMenuItem) -> Void
    let onClose: () -> Void
    
    private let menuWidth: CGFloat = 200
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .opacity(showGridMenu ? 0.12 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(showGridMenu)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        closeMenu()
                    }
                }

            if showGridMenu {
                gridMenu
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.95, anchor: .topTrailing)
                                .combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
    }

    // MARK: - Menu

    private var gridMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visibleMenuItems) { item in
                menuRow(
                    item.title,
                    icon: imageForItem(item),
                    desctructive: item == .delete
                ) {
                    closeMenu()
                    onSelectMenuItem(item)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(width: menuWidth)
        .background(Color.bg(.surface))
        .cornerRadius(24)
        .appBorderModifier(.border(.primary), radius: 24)
        .shadow(color: .black.opacity(0.05), radius: 30)
        .padding(.trailing, 16)
        .offset(y: menuFrame.maxY + 56)
    }

    private func menuRow(
        _ title: String,
        icon: AppIcon,
        desctructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Image(appIcon: icon)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.elements(desctructive ? .destructive : .primary))
                .frame(width: 18, height: 18)

            Text(title)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(desctructive ? .destructive : .primary))

            Spacer()
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
    
    private func imageForItem(_ item: FilesMenuItem) -> AppIcon {
        switch item {
        case .rename:
            return .edit
        case .lock, .unlockDocument:
            return .lock
        case .delete:
            return .trash
        default:
            return .edit
        }
    }
    
    private var visibleMenuItems: [FilesMenuItem] {
        let baseItems: [FilesMenuItem] = [
            .rename,
            .lock,
            .unlockDocument,
            .delete
        ]

        return baseItems.filter {
            switch $0 {
            case .lock: return !isItemLocked
            case .unlockDocument: return isItemLocked
            default: return true
            }
        }
    }
    
    private func closeMenu() {
        showGridMenu = false
        onClose()
    }
}
