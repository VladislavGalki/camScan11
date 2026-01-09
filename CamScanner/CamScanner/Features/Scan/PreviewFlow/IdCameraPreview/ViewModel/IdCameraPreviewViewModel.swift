import Foundation
import UIKit

@MainActor
final class IdCameraPreviewViewModel: ObservableObject {

    @Published var result: IdCaptureResult

    @Published var editingSide: IdCaptureSide = .front

    @Published var selectedFilter: PreviewFilter = .original
    @Published var filteredFront: UIImage?
    @Published var filteredBack: UIImage?
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

    init(result: IdCaptureResult) {
        self.result = result
    }

    var isCompareEnabled: Bool { selectedFilter != .original }

    var frontDisplayImage: UIImage? {
        if isComparingOriginal { return result.front.preview }
        return filteredFront ?? result.front.preview
    }

    var backDisplayImage: UIImage? {
        if isComparingOriginal { return result.back?.preview }
        return filteredBack ?? result.back?.preview
    }

    func onAppear() { recomputeFilters() }

    func selectFilter(_ f: PreviewFilter) {
        selectedFilter = f
        recomputeFilters()
    }

    func recomputeFilters() {
        let front = result.front.preview
        let back = result.back?.preview
        let filter = selectedFilter

        DispatchQueue.global(qos: .userInitiated).async {
            let fFront = front.map { FilterEngine.shared.apply(filter, to: $0) }
            let fBack  = back.map  { FilterEngine.shared.apply(filter, to: $0) }

            DispatchQueue.main.async {
                self.filteredFront = fFront
                self.filteredBack = fBack
            }
        }
    }

    // MARK: - Export

    func export(format: DocumentExportFormat) {
        let images = exportImages()
        guard !images.isEmpty else { return }

        let baseName = "ID_\(result.idType.title)"

        DocumentExporter.shared.exportOrSave(
            images: images,
            format: format,
            fileName: baseName
        ) { res in
            DispatchQueue.main.async {
                switch res {
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
        func pick(original: UIImage?, filtered: UIImage?) -> UIImage? {
            if selectedFilter == .original { return original }
            return filtered ?? original
        }

        var out: [UIImage] = []
        if let f = pick(original: result.front.preview, filtered: filteredFront) { out.append(f) }
        if result.requiresBackSide, let b = pick(original: result.back?.preview, filtered: filteredBack) { out.append(b) }
        return out
    }

    // MARK: - OCR

    func runOCR() {
        guard !isOCRLoading else { return }

        let images = exportImages()
        guard !images.isEmpty else { return }

        isOCRLoading = true
        ocrText = ""

        Task {
            var blocks: [String] = []
            let total = images.count

            for (idx, img) in images.enumerated() {
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

    // MARK: - Save to DB (ID)

    func saveToDatabase() {
        var inputs: [DocumentRepository.PageInput] = []

        if let frontPreview = result.front.preview,
           let frontFull = result.front.original {
            inputs.append(.init(
                displayImage: frontPreview,
                originalFullImage: frontFull,
                quad: result.front.quad,
                filterRaw: selectedFilter.persistKey
            ))
        }

        if result.requiresBackSide,
           let backPreview = result.back?.preview,
           let backFull = result.back?.original {
            inputs.append(.init(
                displayImage: backPreview,
                originalFullImage: backFull,
                quad: result.back?.quad,
                filterRaw: selectedFilter.persistKey
            ))
        }

        guard !inputs.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try DocumentRepository.shared.saveDocument(
                    kind: .id,
                    idTypeRaw: self.result.idType.id,
                    rememberedFilterRaw: self.selectedFilter.persistKey,
                    pages: inputs
                )
            } catch {
                print("!!! Error saving ID: \(error)")
            }
        }
    }

    // MARK: - Crop helpers

    var cropSourceImage: UIImage? {
        switch editingSide {
        case .front: return result.front.original
        case .back:  return result.back?.original
        }
    }

    var cropQuad: Quadrilateral? {
        switch editingSide {
        case .front: return result.front.quad
        case .back:  return result.back?.quad
        }
    }

    func applyCropResult(croppedDisplay: UIImage, quad: Quadrilateral) {
        switch editingSide {
        case .front:
            result.front.preview = croppedDisplay
            result.front.quad = quad

        case .back:
            if result.back == nil { result.back = .init() }
            result.back?.preview = croppedDisplay
            result.back?.quad = quad
        }

        recomputeFilters()
    }
}
