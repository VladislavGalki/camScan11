import Foundation
import UIKit

@MainActor
final class ScanCameraPreviewViewModel: ObservableObject {

    // MARK: - Input/Output

    @Published var pages: [CapturedFrame]

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

    // Crop
    @Published var showCropper: Bool = false
    
    private let previewMode: PreviewMode

    // MARK: - Init

    init(pages: [CapturedFrame], previewMode: PreviewMode, rememberedFilterKey: String?) {
        self.pages = pages
        self.editingIndex = 0
        self.previewMode = previewMode
        self.selectedFilter = PreviewFilter.fromPersistKey(rememberedFilterKey) ?? .original
    }

    // MARK: - Derived

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

    func export(format: DocumentExportFormat, fileName: String = "Scan") {
        let images = exportImages()
        guard !images.isEmpty else { return }

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

    // MARK: - Save to DB (Scan)

    func saveOrUpdate(kind: DocumentRepository.DocKind = .scan) {
        let inputs: [DocumentRepository.PageInput] = pages.compactMap { p in
            guard let display = p.preview, let full = p.original else { return nil }
            return DocumentRepository.PageInput(
                displayImage: display,
                originalFullImage: full,
                quad: p.quad,
                filterRaw: nil
            )
        }
        
        guard !inputs.isEmpty else { return }

        let remembered = selectedFilter.persistKey

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                switch self.previewMode {
                case .newFromCamera:
                    _ = try DocumentRepository.shared.saveDocument(
                        kind: kind,
                        idTypeRaw: nil,
                        rememberedFilterRaw: remembered,
                        pages: inputs
                    )

                case .existing(let docID):
                    try DocumentRepository.shared.updateDocument(
                        docID: docID,
                        kind: kind,
                        idTypeRaw: nil,
                        rememberedFilterRaw: remembered,
                        pages: inputs
                    )
                }
            } catch {
                print("!!! Error saveOrUpdate scan:", error)
            }
        }
    }

    // MARK: - Crop apply

    /// UI отдаёт сюда результат кропа, а наружу (камера/хранилище) — через closure.
    func applyCropResult(index: Int, newDisplay: UIImage, newQuad: Quadrilateral?) {
        guard pages.indices.contains(index) else { return }

        pages[index].preview = newDisplay
        pages[index].quad = newQuad

        filteredPages[index] = nil
        recomputeFilter(for: index)
    }
}
