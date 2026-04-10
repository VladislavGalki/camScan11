import Foundation
import Combine
import UIKit

@MainActor
final class PlaceSignatureViewModel: ObservableObject {
    // MARK: - Published

    @Published var models: [ScanPreviewModel] = []
    @Published var selectedIndex: Int = 0
    @Published var signatureItems: [DocumentSignatureItem] = []
    @Published var selectedSignatureID: UUID?

    @Published var isSaveEnabled = false
    @Published var bubbleAnchor: SignatureBubbleAnchor?

    @Published var shouldShowStyleSheet = false
    @Published var styleDraftColorHex: String = "#020202FF"
    @Published var styleDraftThickness: CGFloat = 10
    @Published var styleDraftOpacity: CGFloat = 1.0

    // MARK: - Internal

    var hasChanges: Bool { isSaveEnabled }

    var selectedSignatureHasStrokes: Bool {
        guard let selectedSignatureID,
              let item = signatureItems.first(where: { $0.id == selectedSignatureID }) else { return false }
        return item.strokes != nil
    }

    // MARK: - Private

    private var originalSignatureItems: [DocumentSignatureItem] = []
    private var currentPageSize: CGSize = .zero
    private var rasterOriginals: [UUID: UIImage] = [:]
    private var didLoadExisting = false

    private let openDocumentStore: OpenDocumentStore
    private let documentRepository = DocumentRepository.shared
    private let inputModel: PlaceSignatureInputModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(inputModel: PlaceSignatureInputModel) {
        self.inputModel = inputModel
        self.openDocumentStore = OpenDocumentStore(documentID: inputModel.documentID)
        subscribe()
    }
}

// MARK: - Public Actions

extension PlaceSignatureViewModel {
    func saveSignatureItems() {
        try? documentRepository.replaceSignatureOverlays(
            documentID: inputModel.documentID,
            items: signatureItems
        )
    }

    func addInitialSignature() {
        addSignature(entityID: inputModel.signatureEntityID)
    }

    func addSignature(entityID: UUID) {
        let entities = DocumentRepository.shared.fetchSignatures()
        guard let entity = entities.first(where: { $0.id == entityID }) else { return }

        let url = FileStore.shared.url(forRelativePath: entity.imagePath)
        guard let image = UIImage(contentsOfFile: url.path) else { return }

        let imageAspect = image.size.width / max(image.size.height, 1)
        let defaultWidth: CGFloat = 0.35
        let pageAspect = max(currentPageSize.width, 322) / max(currentPageSize.height, 456)
        let defaultHeight = (defaultWidth / imageAspect) * pageAspect

        // Load strokes if available
        var strokes: [Stroke]?
        if let strokeData = entity.strokeData {
            let serializable = try? JSONDecoder().decode([SerializableStroke].self, from: strokeData)
            strokes = serializable?.map { $0.toStroke() }
        }

        let item = DocumentSignatureItem(
            id: UUID(),
            pageIndex: selectedIndex,
            signatureEntityID: entity.id,
            centerX: 0.5,
            centerY: 0.5,
            width: defaultWidth,
            height: defaultHeight,
            rotation: 0,
            colorHex: entity.colorHex ?? "#020202FF",
            thickness: entity.brushSize > 0 ? entity.brushSize : 10,
            opacity: 1.0,
            image: image,
            aspectRatio: imageAspect,
            strokes: strokes
        )

        signatureItems.append(item)
        selectedSignatureID = item.id
    }

    func selectSignature(_ id: UUID?) {
        guard let id else {
            clearSelection()
            return
        }

        if selectedSignatureID == id, !shouldShowStyleSheet {
            clearSelection()
            return
        }

        selectedSignatureID = id
        bubbleAnchor = nil
    }

    func clearSelection() {
        selectedSignatureID = nil
        bubbleAnchor = nil
    }

    func moveSignature(id: UUID, to center: CGPoint) {
        guard let index = signatureItems.firstIndex(where: { $0.id == id }) else { return }

        let item = signatureItems[index]
        let minCX = min(item.width / 2, 0.5)
        let maxCX = max(1 - item.width / 2, 0.5)
        let minCY = min(item.height / 2, 0.5)
        let maxCY = max(1 - item.height / 2, 0.5)

        signatureItems[index].centerX = min(max(center.x, minCX), maxCX)
        signatureItems[index].centerY = min(max(center.y, minCY), maxCY)
    }

    func resizeRotateSignature(id: UUID, width: CGFloat, height: CGFloat, rotation: CGFloat) {
        guard let index = signatureItems.firstIndex(where: { $0.id == id }) else { return }

        let clampedWidth = min(max(width, 0.08), 0.9)
        let clampedHeight = clampedWidth / signatureItems[index].aspectRatio *
            (max(currentPageSize.width, 322) / max(currentPageSize.height, 456))

        signatureItems[index].width = clampedWidth
        signatureItems[index].height = clampedHeight
        signatureItems[index].rotation = rotation
    }

    func deleteSelectedSignature() {
        guard let selectedSignatureID else { return }
        bubbleAnchor = nil
        signatureItems.removeAll { $0.id == selectedSignatureID }
        self.selectedSignatureID = nil
    }

    func duplicateSelectedSignature() {
        guard let selectedSignatureID,
              let item = signatureItems.first(where: { $0.id == selectedSignatureID }) else { return }

        var newItem = item
        newItem = DocumentSignatureItem(
            id: UUID(),
            pageIndex: item.pageIndex,
            signatureEntityID: item.signatureEntityID,
            centerX: 0.5,
            centerY: 0.5,
            width: item.width,
            height: item.height,
            rotation: item.rotation,
            colorHex: item.colorHex,
            thickness: item.thickness,
            opacity: item.opacity,
            image: item.image,
            aspectRatio: item.aspectRatio,
            strokes: item.strokes
        )

        bubbleAnchor = nil
        signatureItems.append(newItem)
        self.selectedSignatureID = newItem.id
    }

    func openStyleEditor() {
        guard let selectedSignatureID,
              let item = signatureItems.first(where: { $0.id == selectedSignatureID }) else { return }

        styleDraftColorHex = item.colorHex
        styleDraftThickness = item.thickness
        styleDraftOpacity = item.opacity
        shouldShowStyleSheet = true
    }

    func updateSignatureStyle(colorHex: String? = nil, thickness: CGFloat? = nil, opacity: CGFloat? = nil) {
        guard let selectedSignatureID,
              let index = signatureItems.firstIndex(where: { $0.id == selectedSignatureID }) else { return }

        if let colorHex {
            signatureItems[index].colorHex = colorHex
        }
        if let thickness {
            signatureItems[index].thickness = thickness
        }
        if let opacity {
            signatureItems[index].opacity = opacity
        }

        guard let currentImage = signatureItems[index].image else { return }

        if let strokes = signatureItems[index].strokes, !strokes.isEmpty {
            // Vector (Draw): re-render from strokes
            let color = UIColor(rgbaHex: signatureItems[index].colorHex) ?? .black
            let originalImageSize = CGSize(
                width: currentImage.size.width * currentImage.scale,
                height: currentImage.size.height * currentImage.scale
            )
            if let newImage = SignatureRenderer.render(
                strokes: strokes,
                colorOverride: color,
                brushSizeOverride: signatureItems[index].thickness,
                originalImageSize: originalImageSize
            ) {
                signatureItems[index].image = newImage
            }
        } else if colorHex != nil {
            // Raster (Import/Scan): tint via alpha mask
            let baseImage = rasterOriginals[signatureItems[index].id] ?? currentImage
            if rasterOriginals[signatureItems[index].id] == nil {
                rasterOriginals[signatureItems[index].id] = currentImage
            }
            let color = UIColor(rgbaHex: signatureItems[index].colorHex) ?? .black
            if let tinted = tintImage(baseImage, with: color) {
                signatureItems[index].image = tinted
            }
        }
    }

    func updateBubbleAnchor(_ anchor: SignatureBubbleAnchor?) {
        guard selectedSignatureID != nil else {
            if bubbleAnchor != nil { bubbleAnchor = nil }
            return
        }
        guard bubbleAnchor != anchor else { return }

        DispatchQueue.main.async { [weak self] in
            self?.bubbleAnchor = anchor
        }
    }

    func updateSelectedIndex(_ index: Int) {
        guard models.indices.contains(index) else { return }
        selectedIndex = index
        selectedSignatureID = nil
        bubbleAnchor = nil
    }

    func updateCurrentPageSize(_ size: CGSize) {
        guard size != .zero else { return }
        currentPageSize = size
    }
}

// MARK: - SignaturePageDelegate

extension PlaceSignatureViewModel: SignaturePageDelegate {
    func didTapPage(index: Int) {
        clearSelection()
    }

    func didTapSignature(id: UUID) {
        selectSignature(id)
    }

    func didMoveSignature(id: UUID, to center: CGPoint) {
        moveSignature(id: id, to: center)
    }

    func didResizeRotateSignature(id: UUID, width: CGFloat, height: CGFloat, rotation: CGFloat) {
        resizeRotateSignature(id: id, width: width, height: height, rotation: rotation)
    }

    func didEndResizeRotate(id: UUID) {
        // Reserved for future finalization logic
    }

    func didChangePageSize(_ size: CGSize) {
        updateCurrentPageSize(size)
    }

    func didStartScroll() {
        clearSelection()
    }

    func didChangeSelectedSignatureFrame(id: UUID, rect: CGRect?) {
        guard selectedSignatureID == id, let rect else { return }

        let newAnchor = SignatureBubbleAnchor(
            signatureID: id,
            pageIndex: selectedIndex,
            rect: rect
        )
        updateBubbleAnchor(newAnchor)
    }

    func didChangePage(index: Int) {
        updateSelectedIndex(index)
    }
}

// MARK: - Private

private extension PlaceSignatureViewModel {
    func subscribe() {
        openDocumentStore.previewModelsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] models in
                guard let self else { return }
                self.models = models
                self.selectedIndex = min(self.selectedIndex, max(models.count - 1, 0))

                if !self.didLoadExisting {
                    self.didLoadExisting = true
                    let existing = (try? self.documentRepository.fetchSignatureOverlays(
                        documentID: self.inputModel.documentID
                    )) ?? []

                    if !existing.isEmpty {
                        self.signatureItems = existing
                        self.originalSignatureItems = existing
                    } else {
                        self.addInitialSignature()
                    }
                }
            }
            .store(in: &cancellables)

        $signatureItems
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSaveState()
            }
            .store(in: &cancellables)
    }

    func updateSaveState() {
        isSaveEnabled = signatureItems != originalSignatureItems
    }

    func tintImage(_ image: UIImage, with color: UIColor) -> UIImage? {
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            image.draw(in: rect)
            ctx.cgContext.setBlendMode(.sourceIn)
            ctx.cgContext.setFillColor(color.cgColor)
            ctx.cgContext.fill(rect)
        }
    }
}
