import SwiftUI

struct UnlockDocumentView: View {
    let documentTitle: String
    let onRemove: (() -> Void)?
    let onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            titleView

            subtitleView
                .padding(.bottom, 24)
            
            removeButton

            cancelButton
        }
        .padding(16)
        .frame(width: 300)
        .background(
            Color.bg(.surface)
                .cornerRadius(24)
        )
    }
    
    private var titleView: some View {
        Text("Remove PIN?")
            .appTextStyle(.itemTitle)
            .foregroundStyle(.text(.primary))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
    }
    
    private var subtitleView: some View {
        Text("After that Name of file \(documentTitle) will be unlocked")
            .appTextStyle(.bodyPrimary)
            .foregroundStyle(.text(.secondary))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
    
    private var removeButton: some View {
        AppButton(
            config: AppButtonConfig(
                content: .title("Remove"),
                style: .primary,
                size: .l,
                isFullWidth: true
            ),
            action: {
                onRemove?()
            }
        )
    }
    
    private var cancelButton: some View {
        AppButton(
            config: AppButtonConfig(
                content: .title("Cancel"),
                style: .secondary,
                size: .l,
                isFullWidth: true
            ),
            action: {
                onCancel?()
            }
        )
    }
}
