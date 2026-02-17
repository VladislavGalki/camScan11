import Foundation

final class ShareViewModel: ObservableObject {
    @Published var formatDocumentModel: [ShareDocumentTypeModel] = []
    @Published var isNeedSplitDocument = false
    @Published var isNeetCreateZipArchve = false
    @Published var isNeedSetPassword = false
    @Published var countOfFilesToShare: Int = 0
    
    private let inputModel: ShareInputModel

    init(inputModel: ShareInputModel) {
        self.inputModel = inputModel
        
        bootstrap()
    }
    
    private func bootstrap() {
        formatDocumentModel = [
            ShareDocumentTypeModel(type: .pdf, image: .pdfImage, isSelected: true),
            ShareDocumentTypeModel(type: .jpg, image: .jpgImage),
            ShareDocumentTypeModel(type: .doc, image: .docImage),
            ShareDocumentTypeModel(type: .txt, image: .txtImage),
            ShareDocumentTypeModel(type: .xls, image: .xlsImage),
            ShareDocumentTypeModel(type: .ppt, image: .pptImage),
        ]
        
        // запрос на колл файлов к отправке
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
}
