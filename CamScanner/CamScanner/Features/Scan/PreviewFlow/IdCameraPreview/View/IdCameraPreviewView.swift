import SwiftUI
import UIKit

struct IdCameraPreviewView: View {
    @StateObject private var vm: IdCameraPreviewViewModel
    
    let onDone: () -> Void
    let onRetake: (() -> Void)?
    let onEdit: ((_ side: IdCaptureSide, _ croppedOriginal: UIImage, _ quad: Quadrilateral) -> Void)?

    init(
        inputModel: IdPreviewInputModel,
        onDone: @escaping () -> Void,
        onRetake: (() -> Void)? = nil,
        onEdit: ((_ side: IdCaptureSide, _ croppedOriginal: UIImage, _ quad: Quadrilateral) -> Void)? = nil
    ) {
        self.onEdit = onEdit
        self.onDone = onDone
        self.onRetake = onRetake
        _vm = StateObject(wrappedValue: IdCameraPreviewViewModel(
            result: inputModel.result,
            previewMode: inputModel.previewMode,
            rememberedFilterKey: inputModel.selectedFilterKey)
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
        }
        .onAppear { vm.onAppear() }
        .fullScreenCover(isPresented: $vm.showCropper) { cropperSheet }
        .sheet(isPresented: $vm.showShareSheet) {
            if vm.shareItems.count > 0 {
                DocumentExporterSheet(items: vm.shareItems) {
                    vm.shareItems = []
                }
            }
        }
        .sheet(isPresented: $vm.showOCR) {
            OCREditorView(title: "Текст (OCR)", text: $vm.ocrText) {
                vm.showOCR = false
            }
        }
        .confirmationDialog("Экспорт", isPresented: $vm.showExportDialog, titleVisibility: .visible) {
            ForEach(DocumentExportFormat.allCases) { format in
                Button(format.rawValue) { vm.export(format: format) }
                    .disabled(!format.isImplemented)
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.result.requiresBackSide {
            VStack(spacing: 12) {
                if let img = vm.frontDisplayImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .overlay(alignment: .topLeading) {
                            Text("Лицевая")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                        .onTapGesture { vm.editingSide = .front }
                }

                if let img = vm.backDisplayImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .overlay(alignment: .topLeading) {
                            Text("Оборот")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                        .onTapGesture { vm.editingSide = .back }
                }
            }
            .padding(.top, 56)
            .padding(.bottom, 170)
            .padding(.horizontal, 16)
        } else {
            if let img = vm.frontDisplayImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(.top, 56)
                    .padding(.bottom, 170)
            }
        }
    }

    private var topBar: some View {
        HStack {
            if let onRetake {
                Button(action: onRetake) {
                    Text("Переснять").font(.system(size: 17))
                }
                .foregroundColor(.blue)
            }
        
            Spacer()

            Text(vm.result.idType.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button { vm.showExportDialog = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.blue)
            .padding(.trailing, 8)

            Button {
                vm.saveOrUpdate()
                onDone()
            } label: {
                Text("Готово").font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {

            FiltersCarouselView(selected: Binding(
                get: { vm.selectedFilter },
                set: { vm.selectFilter($0) }
            ))

            if vm.result.requiresBackSide {
                HStack(spacing: 12) {
                    Button { vm.editingSide = .front } label: {
                        Text("Лицевая")
                            .font(.system(size: 13, weight: vm.editingSide == .front ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(vm.editingSide == .front ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Button { vm.editingSide = .back } label: {
                        Text("Оборот")
                            .font(.system(size: 13, weight: vm.editingSide == .back ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(vm.editingSide == .back ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(.white)
            }

            HStack(spacing: 12) {

                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye")
                        Text("Сравнить")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(vm.isCompareEnabled ? 0.10 : 0.05))
                    .foregroundColor(Color.white.opacity(vm.isCompareEnabled ? 1.0 : 0.45))
                    .clipShape(Capsule())
                }
                .disabled(!vm.isCompareEnabled)
                .onLongPressGesture(
                    minimumDuration: 0.01,
                    maximumDistance: 60,
                    pressing: { pressing in
                        guard vm.isCompareEnabled else { return }
                        vm.isComparingOriginal = pressing
                    },
                    perform: {}
                )

                Button {
                    vm.runOCR()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "text.viewfinder")
                        Text(vm.isOCRLoading ? "OCR..." : "Текст")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(vm.isOCRLoading)

                Button {
                    vm.showCropper = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "crop")
                        Text("Обрезка")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 22)
        .padding(.top, 10)
        .background(Color.black.opacity(0.001))
    }

    @ViewBuilder
    private var cropperSheet: some View {
        if let source = vm.cropSourceImage {
            DocumentCropperView(
                originalImage: source,
                autoQuad: vm.cropQuad,
                onCancel: { vm.showCropper = false },
                onDone: { cropped, newQuad in
                    vm.applyCropResult(croppedDisplay: cropped, quad: newQuad)
                    onEdit?(vm.editingSide, cropped, newQuad)
                    vm.showCropper = false
                }
            )
        } else {
            Color.black.ignoresSafeArea()
                .overlay { ProgressView().tint(.white) }
                .onAppear { vm.showCropper = false }
        }
    }
}
