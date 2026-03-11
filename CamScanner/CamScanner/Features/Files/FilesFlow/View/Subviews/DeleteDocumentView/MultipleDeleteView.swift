import SwiftUI

struct MultipleDeleteView: View {
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            titleView

            subtitleView
                .padding(.bottom, 24)

            buttonsView
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .foregroundStyle(.bg(.surface))
        )
        .frame(maxWidth: 300)
    }
    
    var titleView: some View {
        Text("Delete selected files")
            .multilineTextAlignment(.center)
            .appTextStyle(.itemTitle)
            .foregroundStyle(.text(.primary))
            .padding(.bottom, 8)
    }

    var subtitleView: some View {
        Text("These files after delete will not be recoverable. Delete?")
            .multilineTextAlignment(.center)
            .appTextStyle(.bodyPrimary)
            .foregroundStyle(.text(.secondary))
    }

    var buttonsView: some View {
        VStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .title("Delete"),
                    style: .secondary,
                    size: .l,
                    extraTitleColor: .text(.destructive),
                    isFullWidth: true
                ),
                action: onDelete
            )

            AppButton(
                config: AppButtonConfig(
                    content: .title("Cancel"),
                    style: .secondary,
                    size: .l,
                    isFullWidth: true
                ),
                action: onCancel
            )
        }
    }
}
