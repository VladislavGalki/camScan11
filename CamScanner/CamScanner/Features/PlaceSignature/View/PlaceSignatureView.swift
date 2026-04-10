import SwiftUI
import PhotosUI

struct PlaceSignatureView: View {
    @StateObject private var viewModel: PlaceSignatureViewModel
    @State private var shouldShowDeleteConfirmation = false
    @State private var shouldShowExitConfirmation = false
    @State private var showSignaturePicker = false
    @State private var showSignatureSheet = false
    @State private var showCreateSignature = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var signatureCropperModel: DocumentCropperModel?
    @State private var signatureToDelete: SignatureEntity?
    @EnvironmentObject private var router: Router

    init(inputModel: PlaceSignatureInputModel) {
        _viewModel = StateObject(wrappedValue: PlaceSignatureViewModel(inputModel: inputModel))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                navigationBar
                    .padding(.bottom, 16)

                pageIndicator
                    .padding(.bottom, 51)

                carouselView
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 117)
                
                bottomPannel
            }

            bubbleOverlay
                .opacity(viewModel.shouldShowStyleSheet ? 0 : 1)
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.bg(.main).ignoresSafeArea())
        .sheet(
            isPresented: $viewModel.shouldShowStyleSheet,
            onDismiss: {
                viewModel.shouldShowStyleSheet = false
            }
        ) {
            SignatureStyleSheetView(
                mode: viewModel.selectedSignatureHasStrokes ? .vector : .raster,
                initialColorHex: viewModel.styleDraftColorHex,
                initialThickness: viewModel.styleDraftThickness,
                initialOpacity: viewModel.styleDraftOpacity,
                onColorChanged: { viewModel.updateSignatureStyle(colorHex: $0) },
                onThicknessChanged: { viewModel.updateSignatureStyle(thickness: $0) },
                onOpacityChanged: { viewModel.updateSignatureStyle(opacity: $0) }
            )
            .id(viewModel.selectedSignatureID)
            .presentationDetents([.height(160)])
            .presentationBackgroundInteraction(.enabled)
            .presentationCornerRadius(0)
            .presentationDragIndicator(.hidden)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showSignaturePicker) {
            SignaturePickerBottomSheetView(
                onTapAddNew: {
                    showSignaturePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSignatureSheet = true
                    }
                },
                onSelectSignature: { signature in
                    viewModel.addSignature(entityID: signature.id)
                },
                onDeleteSignature: { signature in
                    signatureToDelete = signature
                }
            )
            .presentationDetents([.height(147)])
            .presentationCornerRadius(24)
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                Color.bg(.main)
            }
        }
        .sheet(isPresented: $showSignatureSheet) {
            SignatureBottomSheetView(
                onTapCreateSignature: {
                    showSignatureSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreateSignature = true
                    }
                },
                onTapScanSignature: {
                    showSignatureSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                    }
                },
                onTapImportFromPhotos: {
                    showSignatureSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPhotoPicker = true
                    }
                }
            )
            .presentationDetents([.height(203)])
            .presentationCornerRadius(24)
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                Color.bg(.main)
            }
        }
        .sheet(isPresented: $showCreateSignature) {
            CreateSignatureView(onSaved: { signatureID in
                viewModel.addSignature(entityID: signatureID)
            })
            .presentationDetents([.large])
            .presentationCornerRadius(38)
            .interactiveDismissDisabled()
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            let pickedItems = items
            selectedPhotoItems = []
            Task {
                let images = await ImageImportHelper.loadImages(from: pickedItems)
                guard !images.isEmpty else { return }
                await openSignatureCropper(with: images[0])
            }
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
        .overlay {
            if shouldShowDeleteConfirmation {
                deleteConfirmationOverlay
            }
        }
        .overlay {
            if shouldShowExitConfirmation {
                exitConfirmationOverlay
            }
        }
        .overlay {
            if let signature = signatureToDelete {
                ZStack {
                    Color.black.opacity(0.24)
                        .ignoresSafeArea()
                        .transaction { $0.animation = nil }

                    DeleteSignatureView(
                        onDelete: {
                            try? DocumentRepository.shared.deleteSignature(id: signature.id)
                            signatureToDelete = nil
                        },
                        onCancel: {
                            signatureToDelete = nil
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Subviews

private extension PlaceSignatureView {
    var navigationBar: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.arrowBack),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    if viewModel.hasChanges {
                        viewModel.shouldShowStyleSheet = false
                        shouldShowExitConfirmation = true
                    } else {
                        router.pop()
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
                    viewModel.saveSignatureItems()
                    router.pop()
                }
            )
            .appButtonEnabled(viewModel.isSaveEnabled)
        }
        .overlay {
            Text("Signature")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(
            Color.bg(.surface)
                .appBorderModifier(.border(.primary), radius: 0)
                .ignoresSafeArea(edges: .top)
        )
    }

    var pageIndicator: some View {
        HStack(spacing: 0) {
            Text("\(viewModel.selectedIndex + 1)/\(viewModel.models.count)")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.onOverlay))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .foregroundStyle(.bg(.overlay))
                )
                .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var carouselView: some View {
        SignatureCarouselRepresentable(
            models: viewModel.models,
            signatureItems: viewModel.signatureItems,
            selectedSignatureID: viewModel.selectedSignatureID,
            isScrollDisabled: viewModel.shouldShowStyleSheet,
            isInteractionDisabled: false,
            delegate: viewModel
        )
    }
    
    var bottomPannel: some View {
        VStack(spacing: 4) {
            Image(appIcon: .plus_small)
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(.elements(.navigationDefault))
                .frame(width: 24, height: 24)
            
            Text("Add signature")
                .appTextStyle(.tabBar)
                .foregroundStyle(.text(.secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 11)
        .padding(.bottom, 19)
        .background(
            Color.bg(.surface)
                .appBorderModifier(.border(.primary), radius: 0)
                .ignoresSafeArea()
        )
        .onTapGesture {
            showSignaturePicker = true
        }
    }

    @ViewBuilder
    var bubbleOverlay: some View {
        if let anchor = viewModel.bubbleAnchor,
           viewModel.selectedSignatureID == anchor.signatureID,
           !viewModel.shouldShowStyleSheet {
            GeometryReader { geo in
                let bubbleSize = CGSize(width: 280, height: 64)
                let horizontalPadding: CGFloat = 8
                let spacing: CGFloat = 16
                let rect = anchor.rect

                let x = min(
                    max(rect.midX - bubbleSize.width / 2, horizontalPadding),
                    geo.size.width - bubbleSize.width - horizontalPadding
                )
                let y = rect.minY - bubbleSize.height - spacing

                let bubbleFrame = CGRect(x: x, y: y, width: bubbleSize.width, height: bubbleSize.height)

                BubbleOverlayHost(frame: bubbleFrame) {
                    SignatureActionBubbleView(
                        isEditEnabled: true
                    ) { action in
                        handleBubbleAction(action)
                    }
                    .frame(width: bubbleSize.width, height: bubbleSize.height)
                }
                .ignoresSafeArea()
                .zIndex(1000)
            }
        }
    }

    var deleteConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .transaction { $0.animation = nil }

            VStack(spacing: 24) {
                Text("Delete the signature?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))

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
                            viewModel.deleteSelectedSignature()
                            shouldShowDeleteConfirmation = false
                        }
                    )

                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Cancel"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: { shouldShowDeleteConfirmation = false }
                    )
                }
            }
            .padding(16)
            .frame(width: 300)
            .background(
                Color.bg(.surface)
                    .cornerRadius(24, corners: .allCorners)
            )
        }
    }

    var exitConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .transaction { $0.animation = nil }

            VStack(spacing: 24) {
                Text("Discard changes and leave?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))

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
                            shouldShowExitConfirmation = false
                            router.pop()
                        }
                    )

                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Cancel"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: { shouldShowExitConfirmation = false }
                    )
                }
            }
            .padding(16)
            .frame(width: 300)
            .background(
                Color.bg(.surface)
                    .cornerRadius(24, corners: .allCorners)
            )
        }
    }
}

// MARK: - Actions

private extension PlaceSignatureView {
    func handleBubbleAction(_ action: SignatureActionType) {
        switch action {
        case .delete:
            viewModel.shouldShowStyleSheet = false
            shouldShowDeleteConfirmation = true
        case .duplicate:
            viewModel.duplicateSelectedSignature()
        case .edit:
            viewModel.openStyleEditor()
        }
    }

    func processSignature(_ croppedImage: UIImage) {
        Task {
            if let id = await SignatureProcessingService.processAndSave(croppedImage: croppedImage) {
                viewModel.addSignature(entityID: id)
            }
        }
    }

    func openSignatureCropper(with image: UIImage) async {
        let normalized = image.normalizedUp()
        let autoQuad = await detectAutoQuad(for: normalized)
        signatureCropperModel = DocumentCropperModel(image: normalized, autoQuad: autoQuad)
    }

    func detectAutoQuad(for image: UIImage) async -> Quadrilateral? {
        guard let ciImage = CIImage(image: image) else { return nil }
        return await withCheckedContinuation { continuation in
            VisionRectangleDetector.rectangle(forImage: ciImage) { quad in
                continuation.resume(returning: quad)
            }
        }
    }
}
