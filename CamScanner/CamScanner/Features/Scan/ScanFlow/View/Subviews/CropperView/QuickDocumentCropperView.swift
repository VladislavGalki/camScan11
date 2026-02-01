import SwiftUI
import UIKit

struct QuickDocumentCropperView: View {
    @ObservedObject var store: ScanStore
    
    let cropperModel: DocumentCropperModel
    
    @State private var action: CropperAction?
    
    let onRetake: () -> Void
    let onConfirm: (DocumentCropperModel) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            DocumentCropperControllerRepresentable(
                cropperModel: cropperModel,
                action: $action,
                onCropped: { cropperModel in
                    DispatchQueue.main.async {
                        onConfirm(cropperModel)
                    }
                }
            )
            .overlay(alignment: .top) {
                Text("Adjust the \(store.ui.selectedDocumentType.title) borders if needed")
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.onHint))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .foregroundStyle(.bg(.hintLight))
                            .appBorderModifier(.border(.hintNeutral), width: 1, radius: 8, corners: .allCorners)
                    )
                    .padding(.top, 16)
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 8) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Retake"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ), action: onRetake
                    )
                    
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Continue"),
                            style: .primary,
                            size: .l,
                            isFullWidth: true
                        ), action: {
                            action = .commit
                        }
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
