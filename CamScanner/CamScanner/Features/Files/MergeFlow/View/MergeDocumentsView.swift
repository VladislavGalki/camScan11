import SwiftUI

struct MergeDocumentsView: View {
    @StateObject private var viewModel: MergeDocumentsViewModel
    
    @State private var showNotificationOverlay = false

    @Environment(\.dismiss) private var dismiss

    init(
        inputModel: MergeDocumentsInputModel,
        onMerge: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: MergeDocumentsViewModel(inputModel: inputModel, onMerge: onMerge)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding(.horizontal, 16)

            listView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg(.main))
        .overlay {
            if showNotificationOverlay {
                notificationDeleteFileView
            }
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
            
            Spacer(minLength: 0)

            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.check),
                    style: .primary,
                    size: .m
                ),
                action: {
                    withAnimation {
                        showNotificationOverlay = true
                    }
                }
            )
            .appButtonEnabled(viewModel.items.count > 1)
        }
        .overlay {
            VStack(spacing: 0) {
                Text("Merge files")
                    .appTextStyle(.topBarTitle)
                    .foregroundStyle(.text(.primary))
                    .multilineTextAlignment(.center)
                
                Text("Move files to change order")
                    .appTextStyle(.meta)
                    .foregroundStyle(.text(.secondary))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 12)
        .background(Color.bg(.main))
    }

    private var listView: some View {
        List {
            ForEach(viewModel.items, id: \.id) { item in
                ListDocumentRow(
                    item: item,
                    highlightedID: nil,
                    shouldHideAllSettings: true,
                    shouldHideSettings: true,
                    onFavouriteClick: { _, _ in },
                    onMenuClick: { _, _ in }
                )
                .listRowSeparator(.visible)
                .listRowBackground(Color.clear)
            }
            .onMove(perform: viewModel.move)
        }
        .environment(\.editMode, .constant(.active))
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color.bg(.main))
    }
    
    private var notificationDeleteFileView: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("Keep original files after merging?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))
                    .padding(.bottom, 24)

                VStack(spacing: 10) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Keep original files"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: {
                            withAnimation {
                                showNotificationOverlay = false
                            }
                            
                            viewModel.handleMergeAction()
                        }
                    )
                    
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Remove original files"),
                            style: .secondary,
                            size: .l,
                            extraTitleColor: .text(.destructive),
                            isFullWidth: true
                        ),
                        action: {
                            withAnimation {
                                showNotificationOverlay = false
                            }
                            
                            viewModel.handleMergeAction(shouldRemoveOriginal: true)
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
                            showNotificationOverlay = false
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
}
