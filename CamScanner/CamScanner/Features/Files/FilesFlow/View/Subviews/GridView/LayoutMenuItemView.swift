import SwiftUI

struct LayoutMenuItemView: View {
    @Binding var showGridMenu: Bool
    
    @EnvironmentObject private var tabBar: TabBarController

    let grideMode: FilesViewMode
    let menuFrame: CGRect
    let onSelectMenuItem: (FilesMenuItem) -> Void
    
    private let menuWidth: CGFloat = 200
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        ZStack {
            Color.black
                .opacity(showGridMenu ? 0.12 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(showGridMenu)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showGridMenu = false
                        tabBar.isTabBarVisible = true
                    }
                }

            if showGridMenu {
                AnchoredLayout(
                    location: menuLocation,
                    anchor: menuAnchor
                ) {
                    gridMenu
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.95, anchor: menuAnchor)
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
            ForEach(FilesMenuItem.allCases) { item in
                menuRow(item.title, icon: imageForItem(item), desctructive: item == FilesMenuItem.delete) {
                    showGridMenu = false
                    tabBar.isTabBarVisible = true
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
    }

    private func menuRow(
        _ title: String,
        icon: AppIcon,
        desctructive: Bool = false,
        closure: (() -> Void)?
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
        .onTapGesture {
            closure?()
        }
    }
    
    private func imageForItem(_ item: FilesMenuItem) -> AppIcon {
        switch item {
        case .share:
            return .share
        case .rename:
            return .edit
        case .lock:
            return .lock
        case .move:
            return .move
        case .delete:
            return .trash
        }
    }
    
    private var safeX: CGFloat {
        let screenWidth = UIScreen.main.bounds.width

        let maxAllowedX = screenWidth - horizontalPadding
        let minAllowedX = menuWidth + horizontalPadding

        return min(max(menuFrame.maxX, minAllowedX), maxAllowedX)
    }
    
    private var showAbove: Bool {
        menuFrame.midY > UIScreen.main.bounds.height / 2
    }

    private var menuLocation: CGPoint {
        let x = safeX
        
        if showAbove {
            return CGPoint(
                x: x,
                y: menuFrame.minY - 10
            )
        } else {
            return CGPoint(
                x: x,
                y: menuFrame.maxY + 10
            )
        }
    }

    private var menuAnchor: UnitPoint {
        showAbove ? .bottomTrailing : .topTrailing
    }
}
