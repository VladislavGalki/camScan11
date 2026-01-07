import SwiftUI
import UIKit

struct CapturePreviewView: View {

    /// ✅ страницы (single/group — без разницы)
    let pages: [CapturedFrame]

    let onDone: () -> Void
    let onRetake: () -> Void

    @StateObject var vm: ScanViewModel

    // какая страница выбрана для редактирования
    @State private var editingIndex: Int = 0

    @State private var showCropper = false

    // фильтры
    @State private var selectedFilter: PreviewFilter = .original
    @State private var filteredPages: [Int: UIImage] = [:]

    // compare
    @State private var isComparingOriginal: Bool = false

    // export state (оставляем как было)
    @State private var showExportDialog: Bool = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let display = displayImage {
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
        .onAppear {
            editingIndex = min(editingIndex, max(0, pages.count - 1))
            recomputeFilter(for: editingIndex)
        }
        .onChange(of: selectedFilter) { _, _ in
            recomputeFilter(for: editingIndex)
        }
        .onChange(of: editingIndex) { _, _ in
            recomputeFilter(for: editingIndex)
        }
        .fullScreenCover(isPresented: $showCropper) {
            cropperSheet
        }
        .sheet(isPresented: $showShareSheet) {
            if shareItems.count > 0 {
                DocumentExporterSheet(items: shareItems) {
                    self.shareItems = []
                }
            }
        }
        .confirmationDialog("Экспорт", isPresented: $showExportDialog, titleVisibility: .visible) {
            ForEach(DocumentExportFormat.allCases) { format in
                Button(format.rawValue) {
                    export(format: format)
                }
                .disabled(!format.isImplemented)
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    // MARK: - TopBar

    private var topBar: some View {
        HStack {
            Button("Переснять") { onRetake() }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Spacer()

            Button {
                showExportDialog = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.blue)
            .padding(.trailing, 8)

            Button("Готово") { onDone() }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    // MARK: - BottomBar

    private var bottomBar: some View {
        VStack(spacing: 12) {

            // ✅ как в Id — фильтры сверху
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(PreviewFilter.allCases, id: \.self) { f in
                        filterChip(f)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.never)

            // ✅ если страниц > 1 — показываем горизонтальный выбор страницы (что редактируем)
            if pages.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(pages.indices, id: \.self) { idx in
                            pageChip(idx)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.never)
            }

            // ✅ Compare + Crop row (как в Id)
            HStack(spacing: 12) {
                compareButton
                    .frame(width: 120)

                Button {
                    showCropper = true
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
                .disabled(currentOriginal == nil)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 22)
    }

    // MARK: - Page selection chip

    private func pageChip(_ idx: Int) -> some View {
        let isSelected = (idx == editingIndex)

        return Text("Стр. \(idx + 1)")
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .onTapGesture { editingIndex = idx }
    }

    // MARK: - Compare

    private var isCompareEnabled: Bool { selectedFilter != .original }

    private var compareButton: some View {
        Button {} label: {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                Text("Сравнить")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(isCompareEnabled ? 0.12 : 0.06))
            .foregroundColor(Color.white.opacity(isCompareEnabled ? 1.0 : 0.45))
            .cornerRadius(12)
        }
        .disabled(!isCompareEnabled)
        .onLongPressGesture(
            minimumDuration: 0.01,
            maximumDistance: 50,
            pressing: { pressing in
                guard isCompareEnabled else { return }
                isComparingOriginal = pressing
            },
            perform: {}
        )
    }

    // MARK: - Filter chip

    private func filterChip(_ f: PreviewFilter) -> some View {
        let isSelected = (f == selectedFilter)

        return Text(f.title)
            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.green : Color.white.opacity(0.85))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.06))
            )
            .onTapGesture { selectedFilter = f }
    }

    // MARK: - Display image

    private var displayImage: UIImage? {
        guard pages.indices.contains(editingIndex) else { return nil }

        let base = pages[editingIndex].preview

        if isComparingOriginal { return base }

        if selectedFilter == .original { return base }

        return filteredPages[editingIndex] ?? base
    }

    private func recomputeFilter(for index: Int) {
        guard pages.indices.contains(index) else { return }
        guard let src = pages[index].preview else {
            filteredPages[index] = nil
            return
        }

        if selectedFilter == .original {
            filteredPages[index] = nil
            return
        }

        let filter = selectedFilter
        DispatchQueue.global(qos: .userInitiated).async {
            let out = FilterEngine.shared.apply(filter, to: src)
            DispatchQueue.main.async {
                filteredPages[index] = out
            }
        }
    }

    // MARK: - Cropper

    private var currentOriginal: UIImage? {
        guard pages.indices.contains(editingIndex) else { return nil }
        return pages[editingIndex].original
    }

    private var currentQuad: Quadrilateral? {
        guard pages.indices.contains(editingIndex) else { return nil }
        return pages[editingIndex].quad
    }

    @ViewBuilder
    private var cropperSheet: some View {
        if let original = currentOriginal {
            DocumentCropperView(
                originalImage: original,      // ✅ FULL
                autoQuad: currentQuad,        // ✅ quad
                onCancel: { showCropper = false },
                onDone: { cropped, newQuad in
                    vm.applyManualEditForScan(index: editingIndex, croppedOriginal: cropped, quad: newQuad)
                    showCropper = false

                    // после редактирования — сбросим фильтр-кэш страницы
                    filteredPages[editingIndex] = nil
                    recomputeFilter(for: editingIndex)
                }
            )
        } else {
            Color.black.ignoresSafeArea()
                .overlay { ProgressView().tint(.white) }
                .onAppear { showCropper = false }
        }
    }

    // MARK: - Export

    private func export(format: DocumentExportFormat) {
        let images = exportImages()
        guard !images.isEmpty else { return }

        DocumentExporter.shared.exportOrSave(
            images: images,
            format: format,
            fileName: "Scan"
        ) { result in
            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }
                self.shareItems = urls
                self.showShareSheet = true
            case .failure:
                break
            }
        }
    }

    private func exportImages() -> [UIImage] {
        // экспортируем то, что видит пользователь: выбранный фильтр применяется к каждой странице
        let originals = pages.compactMap { $0.preview }

        if selectedFilter == .original {
            return originals
        }

        return originals.map { FilterEngine.shared.apply(selectedFilter, to: $0) }
    }
}
