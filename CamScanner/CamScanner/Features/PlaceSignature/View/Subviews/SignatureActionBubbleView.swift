import SwiftUI

struct SignatureActionBubbleView: View {
    let isEditEnabled: Bool
    let onAction: (SignatureActionType) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ForEach(SignatureActionType.allCases) { item in
                Text(item.title)
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(foregroundColor(for: item))
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if item == .edit && !isEditEnabled { return }
                        onAction(item)
                    }

                if item != SignatureActionType.allCases.last {
                    Rectangle()
                        .frame(width: 1, height: 20)
                        .foregroundStyle(.divider(.default))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .foregroundStyle(.bg(.surface))
                .appBorderModifier(.border(.primary), radius: 100, corners: .allCorners)
        )
        .contentShape(Capsule())
        .shadow(color: .black.opacity(0.05), radius: 30)
    }

    private func foregroundColor(for item: SignatureActionType) -> Color {
        if item == .edit && !isEditEnabled {
            return .text(.tertiary)
        }
        return item.isDestructive ? .text(.destructive) : .text(.primary)
    }
}
