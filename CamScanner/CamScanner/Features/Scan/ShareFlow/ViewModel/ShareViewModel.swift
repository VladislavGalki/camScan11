import Foundation

final class ShareViewModel: ObservableObject {
    @Published var documentName: String = ""
    @Published var sharePreviewModel: [SharePreviewModel] = []
    @Published var formatDocumentModel: [ShareDocumentTypeModel] = []
    @Published var isNeedSplitDocument = false
    @Published var isNeetCreateZipArchve = false
    @Published var isNeedSetPassword = false
    @Published var passwordText: String = ""
    @Published var countOfFilesToShare: Int = 0
    
    @Published var shareActiveSheet: ShareActiveSheet?
    @Published var shareSheetURLs: [URL] = []
    
    private let inputModel: ShareInputModel

    init(inputModel: ShareInputModel) {
        self.inputModel = inputModel
        
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
        
        passwordText = "Only for PDF files"
        
        // запрос на колл шейров
        updateShareCount()
    }
    
    private func covertInputModel() -> [SharePreviewModel] {
        var result: [SharePreviewModel] = []

        inputModel.pages.forEach { entry in
            let type = entry.documentType

            if type == .documents {
                entry.frames.forEach { frame in
                    result.append(
                        SharePreviewModel(
                            documentType: type,
                            frames: [frame],
                            isSelected: true
                        )
                    )
                }
            } else {
                result.append(
                    SharePreviewModel(
                        documentType: type,
                        frames: entry.frames,
                        isSelected: true
                    )
                )
            }
        }

        return result
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
        
        switch format.type {
        case .pdf:
            do {
                let urls = try ShareExportService.shared.exportPDF(
                    documents: selected,
                    split: isNeedSplitDocument,
                    zip: isNeetCreateZipArchve,
                    password: isNeedSetPassword ? "123456" : nil,
                    addWatermark: true,
                    fileName: documentName
                )

                shareSheetURLs = urls
                shareActiveSheet = .exportShareSheet
            } catch {}
        case .jpg:
            do {
                let urls = try ShareExportService.shared.exportJPG(
                    documents: selected,
                    zip: isNeetCreateZipArchve,
                    fileName: documentName
                )
                
                shareSheetURLs = urls
                shareActiveSheet = .exportShareSheet
            } catch {}
            
        default:
            return
        }
    }
}
