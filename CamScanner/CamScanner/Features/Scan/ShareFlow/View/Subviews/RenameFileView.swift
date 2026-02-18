import SwiftUI

struct RenameFileView: View {
    @State private var newTextFileName: String = ""
    @Binding var documentFileName: String
    
    @Environment(\.dismiss) private var dismiss
    
    init(documentFileName: Binding<String>) {
        newTextFileName = documentFileName.wrappedValue
        _documentFileName = documentFileName
    }
    
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
            
            Text("Rename title")
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
                    documentFileName = newTextFileName
                    dismiss()
                }
            )
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
            TextField("", text: $newTextFileName)
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.black)
                .tint(.bg(.accent))
                .truncationMode(.tail)
                .background(Color.clear)
                .onSubmit {
                    documentFileName = newTextFileName
                    dismiss()
                }
            
            if !newTextFileName.isEmpty {
                Image(appIcon: .closeFill)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.tetriary))
                    .onTapGesture {
                        newTextFileName = ""
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
