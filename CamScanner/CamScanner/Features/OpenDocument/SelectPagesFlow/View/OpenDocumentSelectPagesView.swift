import SwiftUI

struct OpenDocumentSelectPagesView: View {
    @StateObject private var viewModel: OpenDocumentSelectPagesViewModel
    @State private var showDeleteOverlay = false
    @State private var moveInputModel: OpenDocumentSelectPagesMoveInputModel?
    @State private var shouldShowNotification = false
    @State private var notificationModel: NotificationModel?

    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24)
    ]

    init(inputModel: OpenDocumentSelectPagesInputModel, dependencies: AppDependencies) {
        _viewModel = StateObject(
            wrappedValue: OpenDocumentSelectPagesViewModel(
                inputModel: inputModel,
                dependencies: dependencies
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationView

            listView
                .frame(maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .background(Color.bg(.main))
        .overlay(alignment: .top) {
            if shouldShowNotification {
                NotificationToast(
                    isPresented: $shouldShowNotification,
                    title: notificationModel?.title ?? ""
                )
            }
        }
        .overlay {
            if showDeleteOverlay {
                deleteOverlay
            }
        }
        .sheet(item: $moveInputModel) { inputModel in
            OpenDocumentSelectPagesMoveView(
                inputModel: inputModel,
                onComplete: { result in
                    handleMoveCompletion(result)
                    moveInputModel = nil
                },
                dependencies: dependencies
            )
            .presentationCornerRadius(38)
        }
        .navigationBarBackButtonHidden()
    }
}

private extension OpenDocumentSelectPagesView {
    var navigationView: some View {
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

            Text(viewModel.isAllSelected ? "Deselect All" : "Select All")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.accent))
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.10)) {
                        viewModel.toggleSelectAll()
                    }
                }
        }
        .overlay {
            Text("\(viewModel.selectedCount) selected")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.bg(.surface)
                .appBorderModifier(.border(.primary), radius: 0)
                .ignoresSafeArea(edges: .top)
        )
    }

    var listView: some View {
        GeometryReader { geo in
            let cellWidth = floor(max(0, geo.size.width - 32 - 24) / 2)
            let cellHeight = max(0, cellWidth * (243.0 / 172.0))

            ScrollView(.vertical) {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(viewModel.pages) { item in
                        OpenDocumentSelectPageItemView(
                            item: item,
                            isSelected: viewModel.selectedPageIndexes.contains(item.index),
                            cellHeight: cellHeight,
                            onTap: {
                                withAnimation(.easeIn(duration: 0.10)) {
                                    viewModel.toggleSelection(index: item.index)
                                }
                            }
                        )
                    }
                }
                .padding(16)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    var bottomBar: some View {
        HStack(spacing: 0) {
            bottomItem(icon: .move, title: "Move") {
                moveInputModel = viewModel.makeMoveInputModel()
            }
            bottomItem(icon: .share, title: "Share") {
                if let inputModel = viewModel.makeShareInputModel() {
                    router.presentSheet(OpenDocumentRoute.share(inputModel))
                }
            }
            bottomItem(icon: .trash, title: "Delete", destructive: true) {
                withAnimation {
                    showDeleteOverlay = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    func bottomItem(
        icon: AppIcon,
        title: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isDisabled = !viewModel.hasSelectedPages

        let iconStyle: Color = {
            if isDisabled {
                return destructive ? .elements(.destructiveDisabled) : .elements(.disabled)
            }

            return destructive ? .elements(.destructive) : .elements(.secondary)
        }()

        let textStyle: Color = {
            if isDisabled {
                return destructive ? .text(.destructiveDisabled) : .text(.disabled)
            }

            return destructive ? .text(.destructive) : .text(.secondary)
        }()

        return VStack(spacing: 4) {
            Image(appIcon: icon)
                .renderingMode(.template)
                .foregroundStyle(iconStyle)

            Text(title)
                .appTextStyle(.tabBar)
                .foregroundStyle(textStyle)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled {
                action()
            }
        }
    }

    var deleteOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Delete selected files?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))
                    .padding(.bottom, 8)

                Text("These files after delete will not be recoverable. Delete?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.secondary))
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
                        action: {
                            let result = viewModel.deleteSelectedPages()
                            showDeleteOverlay = false

                            if case .deletedDocument = result {
                                router.popToRoot()
                            }
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
                            showDeleteOverlay = false
                        }
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .foregroundStyle(.bg(.surface))
            )
            .frame(maxWidth: 320)
            .padding(.horizontal, 16)
        }
    }

    func handleMoveCompletion(_ result: OpenDocumentSelectPagesMoveResult) {
        switch result {
        case .moved(let count):
            notificationModel = .multipleMoved(count)
            shouldShowNotification = true
            viewModel.reloadAndClearSelection()
        case .movedAndClosedSource(let count):
            NotificationCenter.default.post(
                name: .appGlobalToastRequested,
                object: nil,
                userInfo: ["title": NotificationModel.multipleMoved(count).title]
            )
            router.popToRoot()
        case .failed:
            break
        }
    }
}

private struct OpenDocumentSelectPageItemView: View {
    let item: OpenDocumentSelectablePageItem
    let isSelected: Bool
    let cellHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        Rectangle()
            .foregroundStyle(Color.bg(.surface))
            .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 1)
            .overlay {
                pagePreview
            }
            .overlay(alignment: .topLeading) {
                Image(appIcon: isSelected ? .selectableCheck : .unselectableCheck)
                    .padding(4)
            }
            .background {
                highlitedView
                    .cornerRadius(8, corners: .allCorners)
                    .padding(-8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    var pagePreview: some View {
        switch item.model.documentType {
        case .documents:
            if let image = item.firstPreview {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        case .idCard, .driverLicense:
            VStack(spacing: 6) {
                if let image = item.firstPreview {
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
        case .passport:
            if let image = item.firstPreview {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        default:
            EmptyView()
        }
    }
    
    private var highlitedView: some View {
        isSelected ? Color(hex: "#0088FF")?.opacity(0.10) : Color.clear
    }
}
