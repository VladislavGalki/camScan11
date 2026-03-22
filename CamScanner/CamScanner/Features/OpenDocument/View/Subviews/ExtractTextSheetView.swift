import SwiftUI

struct ExtractTextSheetView: View {
    @Binding var text: String
    let documentName: String
    let onDismiss: () -> Void

    @FocusState private var isEditing: Bool
    @State private var sharePayload: ExtractSharePayload?
    @State private var showCopiedToast = false
    @State private var showDiscardAlert = false
    @State private var originalText: String = ""

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView
                    .padding(.bottom, 22)

                textEditorView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)

                Spacer(minLength: 0)

                if !isEditing {
                    bottomBarView
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isEditing {
                    hideKeyboardButton
                }
            }
            .overlay(alignment: .top) {
                if showCopiedToast {
                    NotificationToast(
                        isPresented: $showCopiedToast,
                        title: "Copied"
                    )
                }
            }

            if showDiscardAlert {
                discardOverlay
            }
        }
        .background(
            Color.bg(.main)
        )
        .sheet(item: $sharePayload) { payload in
            DocumentExporterSheet(items: payload.items) {
                sharePayload = nil
            }
        }
        .onAppear {
            originalText = text
        }
    }
}

private extension ExtractTextSheetView {
    var headerView: some View {
        HStack {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    handleDismiss()
                }
            )
            
            Spacer(minLength: 0)
        }
        .overlay {
            Text("Tap the text to edit")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    var textEditorView: some View {
        TextEditor(text: $text)
            .appTextStyle(.bodyPrimary)
            .foregroundStyle(.text(.primary))
            .focused($isEditing)
            .scrollContentBackground(.hidden)
            .contentMargins(24)
            .background(
                Color.bg(.surface)
                    .appBorderModifier(.border(.primary), radius: 32)
            )
            .cornerRadius(32)
    }

    var hideKeyboardButton: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            
            HStack(spacing: 4) {
                Image(appIcon: .keyboard)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.accent))
                    .frame(width: 16, height: 16)
                
                Text("Hide")
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.accent))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color.bg(.controlOnMain)
                    .cornerRadius(100)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
            .onTapGesture {
                isEditing = false
            }
        }
    }

    var bottomBarView: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(appIcon: .copy)
                
                Text("Copy text")
                    .appTextStyle(.tabBar)
                    .foregroundStyle(.text(.secondary))
            }
            .frame(maxWidth: .infinity)
            .onTapGesture {
                UIPasteboard.general.string = text
                showCopiedToast = true
            }
            
            VStack(spacing: 4) {
                Image(appIcon: .share)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.primary))
                
                Text("Share")
                    .appTextStyle(.tabBar)
                    .foregroundStyle(.text(.secondary))
            }
            .frame(maxWidth: .infinity)
            .onTapGesture {
                shareAsTXT()
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 19)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .appBorderModifier(.border(.primary), radius: 0)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    var discardOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Discard changes and leave?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))
                    .padding(.bottom, 24)

                VStack(spacing: 10) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Discard changes"),
                            style: .secondary,
                            size: .l,
                            extraTitleColor: .text(.destructive),
                            isFullWidth: true
                        ),
                        action: {
                            showDiscardAlert = false
                            onDismiss()
                        }
                    )

                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Cancel"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: {
                            showDiscardAlert = false
                        }
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

    func handleDismiss() {
        isEditing = false
        if text != originalText {
            showDiscardAlert = true
        } else {
            onDismiss()
        }
    }

    func shareAsTXT() {
        do {
            let url = try TextExporter.shared.exportTXT(
                text: text,
                fileName: documentName.isEmpty ? "Extracted_Text" : documentName
            )
            sharePayload = ExtractSharePayload(items: [url])
        } catch {}
    }
}

private struct ExtractSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
