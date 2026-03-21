import Foundation

final class ShareViewModel: ObservableObject {
    @Published var documentName: String = ""
    @Published var sharePreviewModel: [SharePreviewModel] = []
    @Published var formatDocumentModel: [ShareDocumentTypeModel] = []
    @Published var isNeedSplitDocument = false
    @Published var isNeetCreateZipArchve = false
    @Published var isNeedSetPassword = false
    @Published var documentPassword: String?
    @Published var qoutaLimit: Int = 0
    @Published var countOfFilesToShare: Int = 0
    
    @Published var shareActiveSheet: ShareActiveSheet?
    @Published var shareSheetURLs: [URL] = []
    
    @Published var isLoading: Bool = false
    
    private let shareQuotaService = ShareQuotaService.shared
    private let exportService = ShareExportService.shared
    private let inputModel: ShareInputModel

    init(inputModel: ShareInputModel) {
        self.inputModel = inputModel
        shareQuotaService.refreshQuotaIfNeeded()
        bootstrap()
    }
    
    private func bootstrap() {
        documentName = inputModel.documentName
        sharePreviewModel = covertInputModel()
        
        formatDocumentModel = [
            ShareDocumentTypeModel(type: .pdf, image: .pdfImage, isSelected: true),
            ShareDocumentTypeModel(type: .jpg, image: .jpgImage),
            ShareDocumentTypeModel(type: .doc, image: .docImage),
            ShareDocumentTypeModel(type: .txt, image: .txtImage),
            ShareDocumentTypeModel(type: .xls, image: .xlsImage),
            ShareDocumentTypeModel(type: .ppt, image: .pptImage),
        ]
        
        qoutaLimit = shareQuotaService.remainingShares()
        updateShareCount()
    }
    
    private func covertInputModel() -> [SharePreviewModel] {
        print("📤 ShareVM | covertInputModel: pages=\(inputModel.pages.count) textItems=\(inputModel.textItems.count) docType=\(inputModel.documentType) cellHeight=\(inputModel.cellHeight)")
        return inputModel.pages.enumerated().map { index, page in
            let pageTextItems = inputModel.textItems.filter { $0.pageIndex == index }
            print("📤 ShareVM |   page[\(index)] docType=\(page.documentType) frames=\(page.frames.count) textItems=\(pageTextItems.count)")
            for item in pageTextItems {
                print("📤 ShareVM |     \"\(item.text)\" center=(\(item.centerX), \(item.centerY)) size=(\(item.width), \(item.height)) fontSize=\(item.style.fontSize)")
            }
            return SharePreviewModel(
                documentType: page.documentType,
                frames: page.frames,
                textItems: pageTextItems,
                cellHeight: inputModel.cellHeight,
                isSelected: true
            )
        }
    }
    
    private func updateShareCount() {
        let count = sharePreviewModel.filter { $0.isSelected }.count
        countOfFilesToShare = count
    }
    
    func selectDocumentToShare(_ model: SharePreviewModel) {
        sharePreviewModel = sharePreviewModel.map {
            var copy = $0

            if copy.id == model.id {
                copy.isSelected.toggle()
            }

            return copy
        }

        updateShareCount()
    }
    
    func deselectAllDocuments() {
        let updatedModel = sharePreviewModel.map {
            var copy = $0
            copy.isSelected = false
            return copy
        }
        
        sharePreviewModel = updatedModel
        updateShareCount()
    }
    
    var selectedFormatDocument: ShareDocumentTypeModel? {
        formatDocumentModel.first(where: \.isSelected)
    }
    
    func selectFormatDocument(_ selectedDocument: ShareDocumentTypeModel) {
        let updatedModel = formatDocumentModel.map { document in
            var updated = document
            updated.isSelected = document.id == selectedDocument.id
            return updated
        }
        
        formatDocumentModel = updatedModel
    }
    
    func share() {
        guard let format = selectedFormatDocument else { return }
        let selected = sharePreviewModel.filter(\.isSelected)

        print("📤 ShareVM | share: format=\(format.type) selectedPages=\(selected.count)")
        for (i, doc) in selected.enumerated() {
            print("📤 ShareVM |   doc[\(i)] docType=\(doc.documentType) frames=\(doc.frames.count) textItems=\(doc.textItems.count)")
            for item in doc.textItems {
                print("📤 ShareVM |     \"\(item.text)\" center=(\(item.centerX), \(item.centerY)) size=(\(item.width), \(item.height)) fontSize=\(item.style.fontSize)")
            }
        }

        isLoading = true
        
        Task {
            do {
                let urls: [URL]
                
                switch format.type {
                case .pdf:
                    urls = try await Task.detached {
                        try self.exportService.exportPDF(
                            documents: selected,
                            split: self.isNeedSplitDocument,
                            zip: self.isNeetCreateZipArchve,
                            password: self.isNeedSetPassword ? self.documentPassword : nil,
                            addWatermark: true,
                            fileName: self.documentName
                        )
                    }.value
                case .jpg:
                    urls = try await Task.detached {
                        try self.exportService.exportJPG(
                            documents: selected,
                            zip: self.isNeetCreateZipArchve,
                            fileName: self.documentName
                        )
                    }.value
                default:
                    await MainActor.run {
                        self.isLoading = false
                    }
                    
                    return
                }
                
                await MainActor.run {
                    self.shareSheetURLs = urls
                    self.shareActiveSheet = .exportShareSheet
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func updateQoutaShareLimit() {
        do {
            try shareQuotaService.consumeShare()
            qoutaLimit -= 1
        } catch {}
    }
}
