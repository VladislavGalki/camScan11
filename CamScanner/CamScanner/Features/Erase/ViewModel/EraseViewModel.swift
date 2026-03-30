import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class EraseViewModel: ObservableObject {
    // MARK: - Published

    @Published var models: [ScanPreviewModel] = []
    @Published var selectedIndex: Int = 0

    @Published var isAutoColor: Bool = true
    @Published var manualColor: Color = .white
    @Published var brushSize: Double = 20.0

    @Published private(set) var histories: [Int: EraseStrokeHistory] = [:]
    @Published var showDiscardConfirmation = false

    // MARK: - Computed

    var strokesByPage: [Int: [Stroke]] {
        histories.mapValues(\.current)
    }

    var currentStrokes: [Stroke] {
        histories[selectedIndex]?.current ?? []
    }

    var canUndo: Bool {
        histories[selectedIndex]?.canUndo ?? false
    }

    var canRedo: Bool {
        histories[selectedIndex]?.canRedo ?? false
    }

    var hasAnyChanges: Bool {
        histories.values.contains { $0.currentIndex > 0 }
    }

    var activeColor: UIColor {
        if isAutoColor {
            return detectedColors[selectedIndex] ?? .white
        }
        return UIColor(manualColor)
    }

    // MARK: - Private

    private var detectedColors: [Int: UIColor] = [:]
    private let store: EraseStore
    private let documentID: UUID
    private var cancellables = Set<AnyCancellable>()
    private var hasSelectedManualColor = false

    // MARK: - Init

    init(inputModel: EraseInputModel) {
        self.documentID = inputModel.documentID
        self.store = EraseStore(documentID: inputModel.documentID)
        subscribe()
    }

    private func subscribe() {
        store.previewModelsPublisher
            .sink { [weak self] models in
                guard let self else { return }
                Task { @MainActor in
                    self.models = models
                    self.selectedIndex = min(self.selectedIndex, max(models.count - 1, 0))
                    self.detectColorsForAllPages()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func commitStroke(_ stroke: Stroke, onPage pageIndex: Int) {
        DispatchQueue.main.async { [weak self] in
            if self?.histories[pageIndex] == nil {
                self?.histories[pageIndex] = EraseStrokeHistory()
            }
            
            if var current = self?.histories[pageIndex]?.current {
                current.append(stroke)
                
                if self?.histories[pageIndex] != nil {
                    self?.histories[pageIndex]?.push(current)
                }
            }
        }
    }

    func undo() {
        histories[selectedIndex]?.undo()
    }

    func redo() {
        histories[selectedIndex]?.redo()
    }

    func save() {
        var pageImages: [(pageIndex: Int, image: UIImage)] = []

        for (pageIndex, history) in histories where history.currentIndex > 0 {
            guard models.indices.contains(pageIndex),
                  let baseImage = models[pageIndex].frames.first?.preview else { continue }

            let strokes = history.current
            let merged = Self.renderStrokes(strokes, over: baseImage)
            pageImages.append((pageIndex: pageIndex, image: merged))
        }

        guard !pageImages.isEmpty else { return }
        try? store.saveErasedPages(pageImages)
    }

    func setAutoColorEnabled(_ isEnabled: Bool) {
        if !isEnabled && !hasSelectedManualColor {
            manualColor = .white
        }

        isAutoColor = isEnabled
    }

    func selectManualColor(_ color: Color) {
        manualColor = color
        hasSelectedManualColor = true
        isAutoColor = false
    }

    // MARK: - Auto Color Detection

    private func detectColorsForAllPages() {
        for (index, model) in models.enumerated() {
            guard detectedColors[index] == nil,
                  let image = model.frames.first?.preview else { continue }
            detectedColors[index] = Self.detectDominantColor(from: image)
        }
    }

    static func detectDominantColor(from image: UIImage) -> UIColor {
        guard let cgImage = image.cgImage else { return .white }

        let width = cgImage.width
        let height = cgImage.height

        guard width > 4, height > 4 else { return .white }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &pixelData,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return .white }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rSum: Double = 0
        var gSum: Double = 0
        var bSum: Double = 0
        var count: Double = 0

        let margin = 3

        func sample(_ x: Int, _ y: Int) {
            let offset = (y * bytesPerRow) + (x * bytesPerPixel)
            rSum += Double(pixelData[offset])
            gSum += Double(pixelData[offset + 1])
            bSum += Double(pixelData[offset + 2])
            count += 1
        }

        // Sample top and bottom edges
        for x in stride(from: margin, to: width - margin, by: 4) {
            for y in margin..<(margin + 3) {
                sample(x, y)
                sample(x, height - 1 - y)
            }
        }

        // Sample left and right edges
        for y in stride(from: margin, to: height - margin, by: 4) {
            for x in margin..<(margin + 3) {
                sample(x, y)
                sample(width - 1 - x, y)
            }
        }

        guard count > 0 else { return .white }

        return UIColor(
            red: rSum / (count * 255),
            green: gSum / (count * 255),
            blue: bSum / (count * 255),
            alpha: 1
        )
    }

    // MARK: - Render

    static func renderStrokes(_ strokes: [Stroke], over baseImage: UIImage) -> UIImage {
        let base = baseImage.normalizedUp()
        let size = base.size

        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))

            for s in strokes {
                guard !s.points.isEmpty else { continue }

                let color = s.color.withAlphaComponent(s.opacity)
                color.setStroke()

                let path = UIBezierPath()
                let ptsPx = s.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }

                path.move(to: ptsPx[0])

                if ptsPx.count > 1 {
                    for i in 1..<ptsPx.count {
                        let prev = ptsPx[i - 1]
                        let cur = ptsPx[i]
                        let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
                        path.addQuadCurve(to: mid, controlPoint: prev)
                    }
                    if let last = ptsPx.last {
                        path.addLine(to: last)
                    }
                } else {
                    let lw = s.widthN * min(size.width, size.height)
                    let r = max(1, lw / 2)
                    let p = ptsPx[0]
                    color.setFill()
                    UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).fill()
                }

                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.lineWidth = s.widthN * min(size.width, size.height)
                path.stroke()
            }
        }
    }
}

// MARK: - ErasePageDelegate

extension EraseViewModel: ErasePageDelegate {
    func didChangePage(index: Int) {
        guard selectedIndex != index else { return }
        selectedIndex = index
    }

    func didStartScroll() {}

    func didCommitStroke(_ stroke: Stroke, onPage pageIndex: Int) {
        commitStroke(stroke, onPage: pageIndex)
    }
}
