import SwiftUI

struct WatermarkActionBubbleView: View {
    let onAction: (WatermarkActionType) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ForEach(WatermarkActionType.allCases) { item in
                Text(item.title)
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(
                        item.isDestructive
                        ? .text(.destructive)
                        : .text(.primary)
                    )
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onAction(item)
                    }

                if item != .delete {
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
}
