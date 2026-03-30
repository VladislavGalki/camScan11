import SwiftUI

struct OpenDocumentDotsOverlay: View {
    @Binding var isVisible: Bool

    let isLocked: Bool
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
    var menuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(visibleMenuItems) { item in
                menuRow(item) {
                    isVisible = false
                    onSelect(item)
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
                .foregroundStyle(.elements(isDestructive ? .destructive : .primary))
                .frame(width: 18, height: 18)

            Text(item.title)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(isDestructive ? .destructive : .primary))

            Spacer()
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    func icon(for item: OpenDocumentMenuItem) -> AppIcon {
        switch item {
        case .rename:
            return .edit
        case .lock, .unlock:
            return .lock
        case .delete:
            return .trash
        }
    }

    var visibleMenuItems: [OpenDocumentMenuItem] {
        OpenDocumentMenuItem.allCases.filter {
            switch $0 {
            case .lock:
                return !isLocked
            case .unlock:
                return isLocked
            default:
                return true
            }
        }
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
