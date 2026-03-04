import SwiftUI

struct CreateFolderView: View {
    @State private var folderName: String = ""
    
    var onFolderCreated: ((String) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            
            folderImageView
                .padding(.bottom, 48)
            
            folderInputView
                .padding(.horizontal, 16)
            
            Spacer(minLength: 0)
        }
        .background(
            Color.bg(.main)
                .ignoresSafeArea()
        )
    }
    
    private var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    dismiss()
                }
            )
            
            Text("New folder")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.check),
                    style: .primary,
                    size: .m
                ),
                action: {
                    onFolderCreated?(folderName)
                    dismiss()
                }
            )
            .appButtonEnabled(!folderName.isEmpty)
        }
        .padding(.vertical, 12)
    }
    
    private var folderImageView: some View {
        Image(appIcon: .folder_image)
    }
    
    private var folderInputView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.secondary))
            
            textFieldVIew
        }
    }
    
    private var textFieldVIew: some View {
        HStack(spacing: 8) {
            TextField("", text: $folderName)
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.black)
                .tint(.bg(.accent))
                .truncationMode(.tail)
                .background(Color.clear)
                .onSubmit {
                    onFolderCreated?(folderName)
                    dismiss()
                }
            
            if !folderName.isEmpty {
                Image(appIcon: .closeFill)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.tertiary))
                    .onTapGesture {
                        folderName = ""
                    }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 44)
        .background(
            Color.bg(.controlOnMain)
                .cornerRadius(12, corners: .allCorners)
        )
    }
}
