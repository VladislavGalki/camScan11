import SwiftUI

struct DeleteSignatureView: View {
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Delete the signature?")
                .multilineTextAlignment(.center)
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 24)

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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .foregroundStyle(.bg(.surface))
        )
        .frame(maxWidth: 300)
    }
}
