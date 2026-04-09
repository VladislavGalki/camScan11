import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct OpenDocumentView: View {
    @StateObject private var viewModel: OpenDocumentViewModel
    @State private var bottomBarAction: ScanPreviewBottomBarAction?
    @State private var shouldShowDotsOverlay = false
    @State private var isRenameSheetPresented = false
    @State private var overlayState: OpenDocumentOverlayState = .none
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var showSignatureSheet = false
    @State private var showSignaturePickerSheet = false
    @State private var signatureCropperModel: DocumentCropperModel?
    @State private var isSignatureProcessing = false
    @State private var extractedSignatureImage: UIImage?
    @State private var photoImportSource: PhotoImportSource = .addPage
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var importedFileImages: [UIImage] = []
    @State private var activeSheet: OpenDocumentActiveSheet?

    @EnvironmentObject private var router: Router

    @Environment(\.dismiss) private var dismiss

    init(inputModel: OpenDocumentInputModel) {
        _viewModel = StateObject(
            wrappedValue: OpenDocumentViewModel(inputModel: inputModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding(.bottom, 37)

            carouselView
                .frame(maxHeight: .infinity)
                .padding(.bottom, 37)

            filtersView

            bottomBarView
        }
        .navigationBarBackButtonHidden(true)
        .background(
            Color.bg(.main).ignoresSafeArea()
        )
        .ignoresSafeArea(.keyboard, edges: .all)
        .overlay {
            if viewModel.isExtractingText || viewModel.isTranslating {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .transaction { $0.animation = nil }
            }
        }
        .overlay {
            if isSignatureProcessing {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    ExtractSpinnerView()

                    Text("Processing signature")
                        .appTextStyle(.itemTitle)
                        .foregroundStyle(.text(.onImmersive))
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isExtractingText {
                extractingOverlay
                    .transition(.move(edge: .bottom))
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isTranslating {
                translatingOverlay
                    .transition(.move(edge: .bottom))
            }
        }
        .overlay(alignment: .top) {
            if viewModel.shouldShowNotification {
                NotificationToast(
                    isPresented: $viewModel.shouldShowNotification,
                    title: viewModel.notificationModel?.title ?? ""
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.isExtractingText)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.isTranslating)
        .overlayPreferenceValue(OpenDocumentDotsAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if shouldShowDotsOverlay, let anchor {
                    OpenDocumentDotsOverlay(
                        isVisible: $shouldShowDotsOverlay,
                        isLocked: viewModel.isLocked,
                        isFavourite: viewModel.isFavourite,
                        frame: proxy[anchor],
                        onSelect: handleDotsSelection
                    )
                }
            }
        }
        .overlay { modalOverlay }
        .sheet(isPresented: $isRenameSheetPresented) {
            RenameFileView(
                documentFileName: Binding(
                    get: { viewModel.title },
                    set: { viewModel.renameDocument(to: $0) }
                )
            )
            .presentationCornerRadius(38)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case let .move(inputModel):
                MoveDocumentsView(inputModel: inputModel) { documentIds, folderId in
                    viewModel.handleDocumentMoved(documentIds: documentIds, folderId: folderId)
                    activeSheet = nil
                }
                .presentationCornerRadius(38)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.extractedText != nil },
            set: { if !$0 { viewModel.extractedText = nil } }
        )) {
            ExtractTextSheetView(
                text: Binding(
                    get: { viewModel.extractedText ?? "" },
                    set: { viewModel.extractedText = $0 }
                ),
                documentName: viewModel.title,
                onDismiss: { viewModel.extractedText = nil }
            )
            .presentationDetents([.large])
            .presentationCornerRadius(38)
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $viewModel.addPageStarted) {
            AddPageBottomSheetView(
                onTapScan: {
                    router.present(
                        OpenDocumentRoute.scanFlow(
                            ScanInputModel(existingDocumentID: viewModel.documentId),
                            onDismiss: {
                                NotificationCenter.default.post(
                                    name: .openDocumentPreviewDidChange,
                                    object: nil,
                                    userInfo: ["documentID": viewModel.documentId]
                                )
                                viewModel.reloadTextItems()
                                viewModel.reloadWatermarkItems()
                            }
                        )
                    )
                },
                onTapImportFromPhotos: {
                    photoImportSource = .addPage
                    showPhotoPicker = true
                },
                onTapImportFromFiles: {
                    showFilePicker = true
                }
            )
            .presentationDetents([.height(203)])
            .presentationCornerRadius(24)
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                Color.bg(.main)
            }
        }
        .sheet(isPresented: $showSignatureSheet) {
            SignatureBottomSheetView(
                onTapCreateSignature: {
                    router.presentSheet(OpenDocumentRoute.createSignature(onSaved: { signatureID in
                        router.push(OpenDocumentRoute.placeSignature(
                            PlaceSignatureInputModel(documentID: viewModel.documentId, signatureEntityID: signatureID)
                        ))
                    }))
                },
                onTapScanSignature: {
                    router.present(
                        OpenDocumentRoute.scanFlow(
                            ScanInputModel(
                                mode: .signature { image in
                                    processSignature(image)
                                }
                            ),
                            onDismiss: {}
                        )
                    )
                },
                onTapImportFromPhotos: {
                    photoImportSource = .signature
                    showPhotoPicker = true
                }
            )
            .presentationDetents([.height(203)])
            .presentationCornerRadius(24)
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                Color.bg(.main)
            }
        }
        .sheet(isPresented: $showSignaturePickerSheet) {
            SignaturePickerBottomSheetView(
                onTapAddNew: {
                    router.presentSheet(OpenDocumentRoute.createSignature(onSaved: { signatureID in
                        router.push(OpenDocumentRoute.placeSignature(
                            PlaceSignatureInputModel(documentID: viewModel.documentId, signatureEntityID: signatureID)
                        ))
                    }))
                },
                onSelectSignature: { signature in
                    router.push(OpenDocumentRoute.placeSignature(
                        PlaceSignatureInputModel(documentID: viewModel.documentId, signatureEntityID: signature.id)
                    ))
                },
                onDeleteSignature: { signature in
                    overlayState = .signatureDeleteConfirmation(signature)
                }
            )
            .presentationDetents([.height(147)])
            .presentationCornerRadius(24)
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                Color.bg(.main)
            }
        }
        .sheet(isPresented: $viewModel.isTranslatePickerPresented) {
            TranslateLanguagePickerView(
                initialSelection: viewModel.selectedTranslateLanguage ?? viewModel.detectedLanguage
            ) { language in
                viewModel.translateText(to: language)
            }
            .presentationCornerRadius(38)
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.translatedText != nil },
            set: { if !$0 { viewModel.closeTranslator() } }
        )) {
            TranslatorView(
                translatedText: viewModel.translatedText ?? "",
                originalText: viewModel.originalTranslatedText ?? "",
                selectedLanguage: viewModel.selectedTranslateLanguage ?? viewModel.detectedLanguage ?? .english,
                documentName: viewModel.title,
                onDismiss: { viewModel.closeTranslator() },
                onTapLanguage: {
                    viewModel.closeTranslator()
                    reopenTranslatePickerFromTranslator()
                }
            )
            .presentationDetents([.large])
            .presentationCornerRadius(38)
            .presentationDragIndicator(.hidden)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            let source = photoImportSource
            let pickedItems = items
            selectedPhotoItems = []
            Task {
                let images = await ImageImportHelper.loadImages(from: pickedItems)
                guard !images.isEmpty else { return }
                switch source {
                case .addPage:
                    let inputModel = ImageImportHelper.makeCropperInputModel(from: images)
                    router.push(
                        OpenDocumentRoute.scanCropper(
                            inputModel,
                            onFinish: { outputModel in
                                viewModel.addImportedPages(outputModel)
                            }
                        )
                    )
                case .signature:
                    await openSignatureCropper(with: images[0])
                }
            }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerRepresentable { urls in
                let images = ImageImportHelper.loadImages(from: urls)
                if !images.isEmpty {
                    importedFileImages = images
                }
            }
        }
        .onChange(of: importedFileImages) { _, images in
            guard !images.isEmpty else { return }
            importedFileImages = []
            let inputModel = ImageImportHelper.makeCropperInputModel(from: images)
            router.push(
                OpenDocumentRoute.scanCropper(
                    inputModel,
                    onFinish: { outputModel in
                        viewModel.addImportedPages(outputModel)
                    }
                )
            )
        }
        .onAppear {
            viewModel.reloadTextItems()
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { signatureCropperModel != nil },
                set: { if !$0 { signatureCropperModel = nil } }
            )
        ) {
            if let signatureCropperModel {
                SignatureQuickCropperView(
                    cropperModel: signatureCropperModel,
                    onRetake: {
                        self.signatureCropperModel = nil
                        photoImportSource = .signature
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showPhotoPicker = true
                        }
                    },
                    onConfirm: { croppedModel in
                        self.signatureCropperModel = nil
                        processSignature(croppedModel.image)
                    }
                )
            }
        }
    }
}

private extension OpenDocumentView {
    var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.strokeArrowBack),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    dismiss()
                }
            )
            
            Text(viewModel.title)
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.dots),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        shouldShowDotsOverlay = true
                    }
                }
            )
            .anchorPreference(key: OpenDocumentDotsAnchorKey.self, value: .bounds) { $0 }

            AppButton(
                config: AppButtonConfig(
                    content: .title("Share"),
                    style: .primary,
                    size: .m
                ),
                action: {
                    router.presentSheet(
                        OpenDocumentRoute.share(
                            viewModel.makeShareInputModel()
                        )
                    )
                }
            )
        }
        .padding(.bottom, 10)
        .padding(.horizontal, 16)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .appBorderModifier(.border(.primary), width: 1, radius: 0, corners: .allCorners)
                .ignoresSafeArea(edges: .top)
        )
    }
    
    var carouselView: some View {
        OpenDocumentCarouselRepresentable(
            models: viewModel.models,
            textItems: viewModel.textItems,
            watermarkItems: viewModel.watermarkItems,
            actionBottomBarAction: $bottomBarAction,
            onPageChanged: { index in
                viewModel.updateSelectedIndex(index)
            },
            onRotatePage: { index in
                viewModel.rotatePage(at: index)
            },
            onCellHeightChanged: { height in
                viewModel.updateCellHeight(height)
            }
        )
    }
    
    private var filtersView: some View {
        VStack(spacing: 16) {
            FilterCarouselView(
                model: viewModel.filterPreviewItems,
                onFilterSelected: { filter in
                    viewModel.applyFilter(filter)
                }
            )

            AppSlider(value: $viewModel.sliderValue, range: viewModel.currentFilterType.sliderRange)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            viewModel.previewSliderValue(viewModel.sliderValue)
                        }
                        .onEnded { _ in
                            viewModel.commitSliderValue(viewModel.sliderValue)
                        }
                )
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(height: 132)
        .background(
            Color.bg(.surface)
                .appBorderModifier(.border(.primary), width: 1, radius: 0, corners: .allCorners)
        )
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.back),
                        style: .secondary,
                        size: .s
                    ),
                    action: { viewModel.undoFilter() }
                )
                .appButtonEnabled(viewModel.shouldEnableUndoButton)

                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.forward),
                        style: .secondary,
                        size: .s
                    ),
                    action: { viewModel.redoFilter() }
                )
                .appButtonEnabled(viewModel.shouldEnableRedoButton)
            }
            .padding(.horizontal, 16)
            .offset(y: -44)
            .opacity(viewModel.shouldShowFilterStateButton ? 1 : 0)
        }
        .overlay(alignment: .topTrailing) {
            AppButton(
                config: AppButtonConfig(
                    content: .title("Apply to all pages"),
                    style: .secondary,
                    size: .s
                ),
                action: { viewModel.applyFilterToAllPages() }
            )
            .padding(.horizontal, 16)
            .offset(y: -44)
            .opacity(viewModel.shouldShowFilterStateButton ? 1 : 0)
        }
        .disabled(viewModel.filterPreviewItems.contains { !$0.isEnabled })
    }
    
    var bottomBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(OpenDocumentBottomBarActionType.allCases) { item in
                    bottomItem(item)
                        .onTapGesture {
                            handleBottomBarTap(item)
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    var modalOverlay: some View {
        if overlayState != .none {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()

                switch overlayState {
                case .deleteConfirmation:
                    DeleteDocumentView(
                        onDelete: {
                            if viewModel.deleteDocument() {
                                overlayState = .none
                                dismiss()
                            }
                        },
                        onCancel: {
                            overlayState = .none
                        }
                    )
                case .pageDeleteConfirmation:
                    pageDeleteOverlay
                case .lock:
                    LockDocumentView(
                        faceIdRequest: {
                            await viewModel.handleFaceIdRequest()
                        },
                        onSuccess: { pin, viaFaceId in
                            viewModel.createDocumentPin(pin, viaFaceId: viaFaceId)
                            overlayState = .none
                        },
                        onClose: {
                            overlayState = .none
                        }
                    )
                case let .enterPin(menuItem):
                    EnterPinView(
                        documentTitle: viewModel.title,
                        validatePin: { pin in
                            viewModel.validateCurrentDocumentPin(pin)
                        },
                        onSuccess: {
                            switch menuItem {
                            case .delete:
                                overlayState = .deleteConfirmation
                            case .unlock:
                                overlayState = .unlockConfirmation
                            case .addToFavorites,
                                 .removeFromFavorites,
                                 .rename,
                                 .lock,
                                 .move,
                                 .selectPages,
                                 .reorderPages:
                                overlayState = .none
                            }
                        },
                        onClose: {
                            overlayState = .none
                        }
                    )
                case .unlockConfirmation:
                    UnlockDocumentView(
                        documentTitle: viewModel.title,
                        onRemove: {
                            viewModel.removeDocumentPin()
                            overlayState = .none
                        },
                        onCancel: {
                            overlayState = .none
                        }
                    )
                case .signatureDeleteConfirmation(let signature):
                    DeleteSignatureView(
                        onDelete: {
                            try? DocumentRepository.shared.deleteSignature(id: signature.id)
                            overlayState = .none
                        },
                        onCancel: {
                            overlayState = .none
                        }
                    )
                case .none:
                    EmptyView()
                }
            }
        }
    }
    
    func bottomItem(_ item: OpenDocumentBottomBarActionType) -> some View {
        VStack(spacing: 4) {
            Image(appIcon: item.icon)
                .renderingMode(.template)
                .foregroundStyle(
                    item.isDestructive
                    ? .elements(.destructive)
                    : .elements(.secondary)
                )

            Text(item.title)
                .appTextStyle(.tabBar)
                .foregroundStyle(
                    item.isDestructive
                    ? .text(.destructive)
                    : .text(.secondary)
                )
        }
        .frame(width: 70, height: 54)
        .contentShape(Rectangle())
    }
    
    var extractingOverlay: some View {
        VStack(spacing: 0) {
            ExtractSpinnerView()
                .padding(.top, 45)
                .padding(.bottom, 24)

            Text("Recognizing text")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 8)

            Text("You’ll get editable text that you can easily share")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .frame(height: 227)
        .background(
            Color.bg(.surface)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .ignoresSafeArea(edges: .bottom)
        )
    }

    var translatingOverlay: some View {
        VStack(spacing: 0) {
            ExtractSpinnerView()
                .padding(.top, 45)
                .padding(.bottom, 24)

            Text("Translating")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 8)

            Text("Please keep this window open")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Button {
                viewModel.cancelTranslation()
            } label: {
                Text("Cancel")
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.onAccent))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.bg(.accent))
                    .cornerRadius(16)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(
            Color.bg(.surface)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func handleBottomBarTap(_ action: OpenDocumentBottomBarActionType) {
        switch action {
        case .crop:
            router.push(
                OpenDocumentRoute.scanCropper(
                    viewModel.makeCropperInputModel(),
                    onFinish: { outputModel in
                        viewModel.applyCropOutput(outputModel)
                    }
                )
            )
        case .rotate:
            bottomBarAction = .rotate
        case .addPage:
            viewModel.addPageStarted = true
        case .addText:
            router.push(
                OpenDocumentRoute.addText(
                    AddTextInputModel(documentID: viewModel.documentId)
                )
            )
        case .signature:
            if DocumentRepository.shared.fetchSignatures().isEmpty {
                showSignatureSheet = true
            } else {
                showSignaturePickerSheet = true
            }
        case .erase:
            router.push(
                OpenDocumentRoute.erase(
                    EraseInputModel(documentID: viewModel.documentId)
                )
            )
        case .watermark:
            router.push(
                OpenDocumentRoute.watermark(
                    WatermarkInputModel(documentID: viewModel.documentId)
                )
            )
        case .extract:
            viewModel.extractText()
        case .translate:
            viewModel.startTranslateFlow()
        case .delete:
            overlayState = .pageDeleteConfirmation
        }
    }

    private func handleDotsSelection(_ item: OpenDocumentMenuItem) {
        switch item {
        case .addToFavorites:
            viewModel.handleDocumentFavourite(isFavourite: true)
        case .removeFromFavorites:
            viewModel.handleDocumentFavourite(isFavourite: false)
        case .rename:
            isRenameSheetPresented = true
        case .delete:
            viewModel.performLockedMenuAction {
                overlayState = .deleteConfirmation
            } onRequiresPin: {
                overlayState = .enterPin(.delete)
            }
        case .lock:
            overlayState = .lock
        case .unlock:
            viewModel.performLockedMenuAction {
                overlayState = .unlockConfirmation
            } onRequiresPin: {
                overlayState = .enterPin(.unlock)
            }
        case .move:
            activeSheet = .move(viewModel.makeMoveInputModel())
        case .selectPages:
            router.push(OpenDocumentRoute.selectPages(viewModel.makeSelectPagesInputModel()))
        case .reorderPages:
            break
        }
    }

    private func reopenTranslatePickerFromTranslator() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            viewModel.isTranslatePickerPresented = true
        }
    }

    private func openSignatureCropper(with image: UIImage) async {
        let normalized = image.normalizedUp()
        let autoQuad = await detectAutoQuad(for: normalized)
        signatureCropperModel = DocumentCropperModel(image: normalized, autoQuad: autoQuad)
    }

    private func detectAutoQuad(for image: UIImage) async -> Quadrilateral? {
        guard let ciImage = CIImage(image: image) else { return nil }
        return await withCheckedContinuation { continuation in
            VisionRectangleDetector.rectangle(forImage: ciImage) { quad in
                continuation.resume(returning: quad)
            }
        }
    }

    private func processSignature(_ croppedImage: UIImage) {
        isSignatureProcessing = true

        Task.detached(priority: .userInitiated) {
            let renderer = OpenCVFilterRenderer()
            let processed = renderer.extractSignatureWithTransparentBackground(
                image: croppedImage.normalizedUp()
            )

            await MainActor.run {
                isSignatureProcessing = false

                if let processed {
                    extractedSignatureImage = processed
                    NotificationCenter.default.post(
                        name: .appGlobalToastRequested,
                        object: nil,
                        userInfo: ["title": "Signature ready"]
                    )
                } else {
                    NotificationCenter.default.post(
                        name: .appGlobalToastRequested,
                        object: nil,
                        userInfo: ["title": "Unable to process signature"]
                    )
                }
            }
        }
    }

    var pageDeleteOverlay: some View {
        VStack(spacing: 0) {
            Text("Delete the page?")
                .multilineTextAlignment(.center)
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 8)

            Text("You can retake it instead.")
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
                        switch viewModel.deleteSelectedPage() {
                        case .deleted(let pageIndex):
                            overlayState = .none
                            bottomBarAction = .deletePage(pageIndex)
                        case .deletedLastPageDocument:
                            overlayState = .none
                            dismiss()
                        case .failed:
                            overlayState = .none
                        }
                    }
                )

                AppButton(
                    config: AppButtonConfig(
                        content: .title("Retake"),
                        style: .secondary,
                        size: .l,
                        isFullWidth: true
                    ),
                    action: {
                        overlayState = .none
                        viewModel.preparePageRetake()
                        router.present(
                            OpenDocumentRoute.scanFlow(
                                ScanInputModel(existingDocumentID: viewModel.documentId),
                                onDismiss: {
                                    viewModel.completePendingPageRetake()
                                    viewModel.reloadTextItems()
                                    viewModel.reloadWatermarkItems()
                                }
                            )
                        )
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
                        overlayState = .none
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

// MARK: - Import Helpers

private enum PhotoImportSource {
    case addPage
    case signature
}

private struct OpenDocumentDotsAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}
