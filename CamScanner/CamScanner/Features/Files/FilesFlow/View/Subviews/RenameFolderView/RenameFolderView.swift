import SwiftUI

struct RenameFolderView: View {
    @State private var newFolderName: String = ""
    @FocusState private var isFocused: Bool
    
    let folderTitle: String
    let onFinish: ((String) -> Void?)
    
    init(folderTitle: String, onFinish: @escaping (String) -> Void?) {
        self.newFolderName = folderTitle
        self.folderTitle = folderTitle
        self.onFinish = onFinish
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationView
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            
            addressInputView
                .padding(.horizontal, 16)
            
            Spacer(minLength: 0)
        }
        .background(
            Color.bg(.main)
                .ignoresSafeArea()
        )
        .onAppear {
            isFocused = true
        }
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
            
            Text("Rename")
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
                    onFinish(newFolderName)
                    dismiss()
                }
            )
            .appButtonEnabled(!newFolderName.isEmpty)
        }
        .padding(.vertical, 12)
    }
    
    private var addressInputView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Title")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.secondary))
            
            textFieldVIew
        }
    }
    
    private var textFieldVIew: some View {
        HStack(spacing: 8) {
            TextField("", text: $newFolderName)
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.black)
                .tint(.bg(.accent))
                .truncationMode(.tail)
                .background(Color.clear)
                .focused($isFocused)
                .onSubmit {
                    onFinish(newFolderName)
                    dismiss()
                }
            
            if !newFolderName.isEmpty {
                Image(appIcon: .closeFill)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.tertiary))
                    .onTapGesture {
                        newFolderName = ""
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

