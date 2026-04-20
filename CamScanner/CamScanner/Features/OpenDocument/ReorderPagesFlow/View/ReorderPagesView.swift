import SwiftUI

struct ReorderPagesView: View {
    @StateObject private var viewModel: ReorderPagesViewModel
    @State private var showDiscardOverlay = false

    @Environment(\.dismiss) private var dismiss

    private let onSave: () -> Void

    // MARK: - Init

    init(
        inputModel: ReorderPagesInputModel,
        onSave: @escaping () -> Void,
        dependencies: AppDependencies
    ) {
        _viewModel = StateObject(
            wrappedValue: ReorderPagesViewModel(
                inputModel: inputModel,
                dependencies: dependencies
            )
        )
        self.onSave = onSave
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding(.horizontal, 16)

            listView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg(.main))
        .overlay {
            if showDiscardOverlay {
                discardOverlay
            }
        }
    }
}

// MARK: - Subviews

private extension ReorderPagesView {
    var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    if viewModel.hasChanges {
                        showDiscardOverlay = true
                    } else {
                        dismiss()
                    }
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
                    if viewModel.save() {
                        onSave()
                    }
                    dismiss()
                }
            )
            .appButtonEnabled(viewModel.hasChanges)
        }
        .overlay {
            VStack(spacing: 0) {
                Text("Reorder pages")
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

    var listView: some View {
        List {
            ForEach(viewModel.pages) { item in
                reorderPageRow(item)
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

    // MARK: - Row

    func reorderPageRow(_ item: ReorderPageItem) -> some View {
        HStack(spacing: 12) {
            pagePreview(item)
                .frame(width: 40, height: 56)
                .background(Color.bg(.surface))
                .clipped()

            Text(item.title)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.primary))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    func pagePreview(_ item: ReorderPageItem) -> some View {
        switch item.documentType {
        case .idCard, .driverLicense:
            VStack(spacing: 2) {
                if let image = item.preview {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
                if let image = item.secondPreview {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
        default:
            if let image = item.preview {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    // MARK: - Discard Overlay

    var discardOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Discard changes?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))
                    .padding(.bottom, 8)

                Text("Your edits haven't been saved.")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.secondary))
                    .padding(.bottom, 24)

                VStack(spacing: 10) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Keep Editing"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: {
                            showDiscardOverlay = false
                        }
                    )

                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Discard Changes"),
                            style: .secondary,
                            size: .l,
                            extraTitleColor: .text(.destructive),
                            isFullWidth: true
                        ),
                        action: {
                            showDiscardOverlay = false
                            dismiss()
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
