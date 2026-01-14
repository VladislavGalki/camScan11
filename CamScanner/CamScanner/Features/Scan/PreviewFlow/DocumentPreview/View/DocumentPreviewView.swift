import SwiftUI
import UIKit

struct DocumentPreviewView: View {

    @StateObject private var vm: DocumentPreviewViewModel

    let onDone: () -> Void
    let onRetake: (() -> Void)?
    let onEditPage: ((_ index: Int, _ croppedFull: UIImage, _ quad: Quadrilateral) -> Void)?

    init(
        inputModel: DocumentPreviewInputModel,
        onDone: @escaping () -> Void,
        onRetake: (() -> Void)? = nil,
        onEditPage: ((_ index: Int, _ croppedFull: UIImage, _ quad: Quadrilateral) -> Void)? = nil
    ) {
        self.onDone = onDone
        self.onRetake = onRetake
        self.onEditPage = onEditPage
        _vm = StateObject(wrappedValue: DocumentPreviewViewModel(input: inputModel))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let display = vm.displayImage {
                Image(uiImage: display)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }

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

    // MARK: - TopBar

    private var topBar: some View {
        HStack {
            if let onRetake {
                Button("Переснять") { onRetake() }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            Spacer()

            Text(vm.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button { vm.showExportDialog = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.blue)
            .padding(.trailing, 8)

            Button("Готово") {
                vm.saveOrUpdate()
                onDone()
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - BottomBar

    private var bottomBar: some View {
        VStack(spacing: 12) {

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(PreviewFilter.allCases, id: \.self) { f in
                        filterChip(f)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.never)

            if vm.currentPageCount > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(vm.pages.indices, id: \.self) { idx in
                            pageChip(idx)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.never)
            }

            HStack(spacing: 12) {
                compareButton
                    .frame(width: 120)

                Button {
                    vm.runOCRForAllPages()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "text.viewfinder")
                        Text(vm.isOCRLoading ? "OCR..." : "Текст")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(vm.isOCRLoading || vm.pages.isEmpty)

                Button {
                    vm.showCropper = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "crop")
                        Text("Обрезка")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(vm.currentOriginal == nil)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 22)
    }

    private func pageChip(_ idx: Int) -> some View {
        let isSelected = (idx == vm.editingIndex)

        return Text(vm.pageTitle(for: idx))
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .onTapGesture { vm.selectPage(idx) }
    }

    private var compareButton: some View {
        Button {} label: {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                Text("Сравнить")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(vm.isCompareEnabled ? 0.12 : 0.06))
            .foregroundColor(Color.white.opacity(vm.isCompareEnabled ? 1.0 : 0.45))
            .cornerRadius(12)
        }
        .disabled(!vm.isCompareEnabled)
        .onLongPressGesture(
            minimumDuration: 0.01,
            maximumDistance: 50,
            pressing: { pressing in
                guard vm.isCompareEnabled else { return }
                vm.isComparingOriginal = pressing
            },
            perform: {}
        )
    }

    private func filterChip(_ f: PreviewFilter) -> some View {
        let isSelected = (f == vm.selectedFilter)

        return Text(f.title)
            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.green : Color.white.opacity(0.85))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.06))
            )
            .onTapGesture { vm.selectFilter(f) }
    }

    // MARK: - Cropper

    @ViewBuilder
    private var cropperSheet: some View {
        if let original = vm.currentOriginal {
            DocumentCropperView(
                originalImage: original,
                autoQuad: vm.currentQuad,
                onCancel: { vm.showCropper = false },
                onDone: { croppedFull, newQuad in
                    // 1) обновляем локально в превью
                    vm.applyCropResult(
                        index: vm.editingIndex,
                        newDisplay: croppedFull,
                        newQuad: newQuad
                    )
                    // 2) наверх (камера-сессия) — опционально
                    onEditPage?(vm.editingIndex, croppedFull, newQuad)

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
