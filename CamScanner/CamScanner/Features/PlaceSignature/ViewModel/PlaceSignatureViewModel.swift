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

    private let openDocumentStore: OpenDocumentStore
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
    func addInitialSignature() {
        let entities = DocumentRepository.shared.fetchSignatures()
        guard let entity = entities.first(where: { $0.id == inputModel.signatureEntityID }) else { return }

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
            image: image,
            aspectRatio: imageAspect,
            strokes: strokes
        )

        signatureItems.append(item)
        selectedSignatureID = item.id
        originalSignatureItems = signatureItems
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
        shouldShowStyleSheet = true
    }

    func updateSignatureStyle(colorHex: String? = nil, thickness: CGFloat? = nil) {
        guard let selectedSignatureID,
              let index = signatureItems.firstIndex(where: { $0.id == selectedSignatureID }) else { return }

        if let colorHex {
            signatureItems[index].colorHex = colorHex
        }
        if let thickness {
            signatureItems[index].thickness = thickness
        }

        // Re-render image from strokes if available
        guard let strokes = signatureItems[index].strokes, !strokes.isEmpty,
              let currentImage = signatureItems[index].image else { return }

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
                if self.signatureItems.isEmpty {
                    self.addInitialSignature()
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
}
