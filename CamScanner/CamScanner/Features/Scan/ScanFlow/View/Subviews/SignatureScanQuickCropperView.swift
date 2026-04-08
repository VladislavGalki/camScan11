import SwiftUI

struct SignatureScanQuickCropperView: View {
    let cropperModel: DocumentCropperModel
    let onRetake: () -> Void
    let onConfirm: (DocumentCropperModel) -> Void

    @State private var action: CropperAction?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            DocumentCropperControllerRepresentable(
                cropperModel: cropperModel,
                action: $action,
                onCropped: { model in
                    onConfirm(model)
                }
            )
            .ignoresSafeArea()
            .safeAreaInset(edge: .top) {
                Text("Adjust the signature borders if needed")
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.onHint))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .foregroundStyle(.bg(.hintLight))
                            .appBorderModifier(.border(.hintNeutral), width: 1, radius: 8, corners: .allCorners)
                    )
                    .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Retake"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: onRetake
                    )

                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Continue"),
                            style: .primary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: {
                            action = .commit
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
}
