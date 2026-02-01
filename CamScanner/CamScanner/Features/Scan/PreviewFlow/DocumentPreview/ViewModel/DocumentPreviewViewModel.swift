import Foundation
import UIKit

@MainActor
final class DocumentPreviewViewModel: ObservableObject {

    // Input
    @Published var pages: [CapturedFrame]
    let kind: DocumentPreviewKind
    private let previewMode: PreviewMode

    // UI state
    @Published var editingIndex: Int = 0
    @Published var selectedFilter: PreviewFilter = .original
    @Published var filteredPages: [Int: UIImage] = [:]
    @Published var isComparingOriginal: Bool = false

    // Export
    @Published var showExportDialog: Bool = false
    @Published var shareItems: [Any] = []
    @Published var showShareSheet: Bool = false

    // OCR
    @Published var showOCR: Bool = false
    @Published var ocrText: String = ""
    @Published var isOCRLoading: Bool = false

    // Drawing
    @Published var showDrawing: Bool = false
    
    // Crop
    @Published var showCropper: Bool = false

    // MARK: - Init

    init(input: DocumentPreviewInputModel) {
        self.pages = input.pages
        self.kind = input.kind
        self.previewMode = input.previewMode
        self.selectedFilter = PreviewFilter.fromPersistKey(input.rememberedFilterKey) ?? .original
        self.editingIndex = 0
    }

    // MARK: - Derived

    var title: String {
        switch kind {
        case .scan:
            return "Скан"
        case .id(_, let t):
            return t
        }
    }

    var currentPageCount: Int { pages.count }

    var currentOriginal: UIImage? {
        guard pages.indices.contains(editingIndex) else { return nil }
        return pages[editingIndex].original
    }

    var currentQuad: Quadrilateral? {
        guard pages.indices.contains(editingIndex) else { return nil }
        return pages[editingIndex].quad
    }

    var displayImage: UIImage? {
        guard pages.indices.contains(editingIndex) else { return nil }
        let base = pages[editingIndex].preview

        if isComparingOriginal { return base }
        if selectedFilter == .original { return base }
        return filteredPages[editingIndex] ?? base
    }

    var isCompareEnabled: Bool { selectedFilter != .original }
    
    var canOpenDrawing: Bool {
        // рисуем по текущей превьюшке (то, что видит юзер)
        pages.indices.contains(editingIndex) && pages[editingIndex].preview != nil
    }
    
    var currentInitialStrokes: [Stroke] {
        guard pages.indices.contains(editingIndex) else { return [] }
        guard let data = pages[editingIndex].drawingData else { return [] }
        return StrokeCodec.decode(data)
    }

    var currentPreviewForDrawing: UIImage? {
        guard pages.indices.contains(editingIndex) else { return nil }
        return pages[editingIndex].drawingBase ?? pages[editingIndex].preview
    }
    
    var currentDrawingStrokes: [Stroke] {
        guard pages.indices.contains(editingIndex) else { return [] }
        guard let data = pages[editingIndex].drawingData else { return [] }
        return StrokeCodec.decode(data)
    }

    func pageTitle(for index: Int) -> String {
        "Стр. \(index + 1)"
    }

    // MARK: - UI events

    func onAppear() {
        editingIndex = min(editingIndex, max(0, pages.count - 1))
        recomputeFilter(for: editingIndex)
    }

    func selectPage(_ idx: Int) {
        editingIndex = idx
        recomputeFilter(for: idx)
    }

    func selectFilter(_ f: PreviewFilter) {
        selectedFilter = f
        recomputeFilter(for: editingIndex)
    }

    // MARK: - Filters

    func recomputeFilter(for index: Int) {
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
                self.filteredPages[index] = out
            }
        }
    }
    
    // MARK: - Drawing
    func openDrawing() {
        guard canOpenDrawing else { return }
        showDrawing = true
    }

    func applyDrawingResult(_ merged: UIImage, _ strokes: [Stroke]) {
        guard pages.indices.contains(editingIndex) else { return }

        // ✅ база "до рисунка" должна быть неизменной
        if pages[editingIndex].drawingBase == nil {
            pages[editingIndex].drawingBase = pages[editingIndex].preview
        }

        // ✅ strokes храним в drawingData (это единственное что нужно)
        pages[editingIndex].drawingData = StrokeCodec.encode(strokes)

        // ✅ preview обновляем на merged
        pages[editingIndex].preview = merged

        filteredPages[editingIndex] = nil
        recomputeFilter(for: editingIndex)
    }

    // MARK: - OCR

    private func imagesForOCR() -> [UIImage] {
        let base = pages.compactMap { $0.preview }
        guard !base.isEmpty else { return [] }

        if selectedFilter == .original { return base }
        return base.map { FilterEngine.shared.apply(selectedFilter, to: $0) }
    }

    func runOCRForAllPages() {
        guard !isOCRLoading else { return }

        let imgs = imagesForOCR()
        guard !imgs.isEmpty else { return }

        isOCRLoading = true
        ocrText = ""

        Task {
            var blocks: [String] = []
            let total = imgs.count

            for (idx, img) in imgs.enumerated() {
                let pageTitle = "СТРАНИЦА \(idx + 1)/\(total)"
                do {
                    let res = try await OCRService.shared.recognizeText(in: img)
                    blocks.append("\(pageTitle)\n\(res.text)")
                } catch {
                    blocks.append("\(pageTitle)\n(ошибка OCR)")
                }
            }

            self.ocrText = blocks.joined(separator: "\n\n")
            self.isOCRLoading = false
            self.showOCR = true
        }
    }

    // MARK: - Export

    func export(format: DocumentExportFormat) {
        let images = exportImages()
        guard !images.isEmpty else { return }

        let fileName: String = {
            switch kind {
            case .scan:
                return "Scan"
            case .id(_, let t):
                return "ID_\(t)"
            }
        }()

        DocumentExporter.shared.exportOrSave(
            images: images,
            format: format,
            fileName: fileName
        ) { result in
            DispatchQueue.main.async {
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
    }

    private func exportImages() -> [UIImage] {
        let originals = pages.compactMap { $0.preview }
        if selectedFilter == .original { return originals }
        return originals.map { FilterEngine.shared.apply(selectedFilter, to: $0) }
    }

    // MARK: - Save / Update

    func saveOrUpdate() {
        let inputs: [DocumentRepository.PageInput] = pages.enumerated().compactMap { idx, p in
            guard let display = p.preview, let full = p.original else { return nil }

            return DocumentRepository.PageInput(
                displayImage: display,
                originalFullImage: full,
                quad: p.quad,
                drawingData: p.drawingData,
                drawingBaseImage: p.drawingBase,   // ✅ ВАЖНО
                filterRaw: selectedFilter.persistKey
            )
        }

        guard !inputs.isEmpty else { return }

        let remembered = selectedFilter.persistKey

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                switch self.previewMode {
                case .newFromCamera:
                    switch self.kind {
                    case .scan:
                        _ = try DocumentRepository.shared.saveDocument(
                            kind: .scan, idTypeRaw: nil, rememberedFilterRaw: remembered, pages: inputs
                        )
                    case .id(let idTypeRaw, _):
                        _ = try DocumentRepository.shared.saveDocument(
                            kind: .id, idTypeRaw: idTypeRaw, rememberedFilterRaw: remembered, pages: inputs
                        )
                    }

                case .existing(let docID):
                    switch self.kind {
                    case .scan:
                        try DocumentRepository.shared.updateDocument(
                            docID: docID, kind: .scan, idTypeRaw: nil, rememberedFilterRaw: remembered, pages: inputs
                        )
                    case .id(let idTypeRaw, _):
                        try DocumentRepository.shared.updateDocument(
                            docID: docID, kind: .id, idTypeRaw: idTypeRaw, rememberedFilterRaw: remembered, pages: inputs
                        )
                    }
                }
            } catch {
                print("!!! Error saveOrUpdate preview:", error)
            }
        }
    }

    // MARK: - Crop apply

    func applyCropResult(index: Int, cropperModel: DocumentCropperModel) {
        guard pages.indices.contains(index) else { return }

        pages[index].preview = cropperModel.image
        pages[index].quad = cropperModel.autoQuad

        // ✅ рисунок больше невалиден после кропа
        pages[index].drawingBase = nil
        pages[index].drawingData = nil

        filteredPages[index] = nil
        recomputeFilter(for: index)
    }
}
