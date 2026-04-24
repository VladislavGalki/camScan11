import Foundation

final class AppDependencies {
    let persistence: PersistenceController

    lazy var keychainService = KeychainService()
    lazy var passwordCryptoService = PasswordCryptoService()
    lazy var faceIDService = FaceIDService()

    lazy var filterRenderer = FilterRenderer()
    lazy var cropRenderer = CropRenderer()
    lazy var imageCompressionService = ImageCompressionService()
    lazy var filterEngine = FilterEngine()
    lazy var rotationService = RotationService(filterRenderer: filterRenderer)

    lazy var zipService = ZipService()
    lazy var ocrService = OCRService()
    lazy var textExporter = TextExporter()

    lazy var fileStore = FileStore()

    lazy var jpgRenderer = JPGRendererService(
        imageCompressionService: imageCompressionService
    )

    lazy var documentRepository = DocumentRepository(
        context: persistence.container.viewContext,
        passwordCryptoService: passwordCryptoService,
        keychainService: keychainService,
        fileStore: fileStore,
        imageCompressionService: imageCompressionService
    )

    lazy var shareQuotaService = ShareQuotaService(
        keychainService: keychainService
    )

    lazy var documentExporter = DocumentExporter()

    lazy var imageToExcelConverter: ImageToExcelConverting = ImageToExcelConverter()
    lazy var imageToWordConverter: ImageToWordConverting = ImageToWordConverter(ocrService: ocrService)

    lazy var shareExportService = ShareExportService(
        ocrService: ocrService,
        zipService: zipService,
        jpgRenderer: jpgRenderer,
        pdfRendererFactory: { [imageCompressionService] in
            PDFRendererService(imageCompressionService: imageCompressionService)
        },
        excelConverter: imageToExcelConverter,
        wordConverter: imageToWordConverter
    )

    lazy var lockedActionExecutor = LockedActionExecutor(
        faceIdService: faceIDService
    )

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }
}
