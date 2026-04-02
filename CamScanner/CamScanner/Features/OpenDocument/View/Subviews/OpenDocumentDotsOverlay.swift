import SwiftUI

struct OpenDocumentDotsOverlay: View {
    @Binding var isVisible: Bool

    let isLocked: Bool
    let isFavourite: Bool
    let frame: CGRect
    let onSelect: (OpenDocumentMenuItem) -> Void

    private let menuWidth: CGFloat = 200
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        if isVisible {
            ZStack {
                Color.black
                    .opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isVisible = false
                        }
                    }

                AnchoredLayout(
                    location: menuLocation,
                    anchor: menuAnchor
                ) {
                    menuView
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
}

private extension OpenDocumentDotsOverlay {
    enum MenuEntry: Identifiable {
        case item(OpenDocumentMenuItem)
        case separator(String)

        var id: String {
            switch self {
            case .item(let item):
                return "item_\(item.id)"
            case .separator(let value):
                return "separator_\(value)"
            }
        }
    }

    var menuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(menuEntries) { entry in
                switch entry {
                case .item(let item):
                    menuRow(item) {
                        isVisible = false
                        onSelect(item)
                    }
                case .separator:
                    separator
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

    func menuRow(_ item: OpenDocumentMenuItem, action: @escaping () -> Void) -> some View {
        let isDestructive = item == .delete

        return HStack(spacing: 8) {
            Image(appIcon: icon(for: item))
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(iconColor(for: item))
                .frame(width: 18, height: 18)

            Text(item.title)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(isDestructive ? .destructive : .primary))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    func icon(for item: OpenDocumentMenuItem) -> AppIcon {
        switch item {
        case .addToFavorites:
            return .star
        case .removeFromFavorites:
            return .starFill
        case .rename:
            return .edit
        case .lock, .unlock:
            return .lock
        case .move:
            return .move
        case .selectPages:
            return .check_circle
        case .reorderPages:
            return .reorder
        case .delete:
            return .trash
        }
    }

    func iconColor(for item: OpenDocumentMenuItem) -> Color {
        switch item {
        case .delete:
            return .elements(.destructive)
        case .removeFromFavorites:
            return .elements(.warning)
        default:
            return .elements(.primary)
        }
    }

    var menuEntries: [MenuEntry] {
        let favoriteItem: OpenDocumentMenuItem = isFavourite ? .removeFromFavorites : .addToFavorites
        let lockItem: OpenDocumentMenuItem = isLocked ? .unlock : .lock

        return [
            .item(favoriteItem),
            .separator("favorites"),
            .item(.rename),
            .item(lockItem),
            .item(.move),
            .separator("move"),
            .item(.selectPages),
            .item(.reorderPages),
            .separator("pages"),
            .item(.delete)
        ]
    }

    var separator: some View {
        Rectangle()
            .foregroundStyle(.divider(.default))
            .frame(height: 1)
            .padding(.vertical, 8)
    }

    var safeX: CGFloat {
        let maxAllowedX = UIScreen.main.bounds.width - horizontalPadding
        let minAllowedX = menuWidth + horizontalPadding
        return min(max(frame.maxX, minAllowedX), maxAllowedX)
    }

    var menuLocation: CGPoint {
        CGPoint(
            x: safeX,
            y: frame.maxY + 10
        )
    }

    var menuAnchor: UnitPoint {
        .topTrailing
    }
}
