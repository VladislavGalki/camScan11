import Foundation
import UIKit
import CoreData

final class DocumentMergeService {

    static let shared = DocumentMergeService()
    private init() {}

    enum MergeError: Error {
        case nothingToMerge
        case failedToLoadPages
    }

    func mergeDocuments(docIDs: [UUID]) throws -> UUID {
        guard docIDs.count >= 2 else { throw MergeError.nothingToMerge }

        var pageInputs: [DocumentRepository.PageInput] = []

        for docID in docIDs {
            let frames = try DocumentRepository.shared.loadFrames(docID: docID)
            guard !frames.isEmpty else { continue }

            for f in frames {
                guard let display = f.preview, let full = f.original else { continue }

                // ✅ ВАЖНО:
                // если у страницы есть drawingData (strokes), то обязана быть и "чистая база"
                // иначе при открытии merged-дока ластик/редактирование могут не работать корректно.
                let baseForDrawing: UIImage? = {
                    if let b = f.drawingBase { return b }      // ✅ правильная база
                    if f.drawingData != nil { return full }   // ✅ fallback лучше, чем display (display уже с рисунком)
                    return nil
                }()

                pageInputs.append(.init(
                    displayImage: display,
                    originalFullImage: full,
                    quad: f.quad,
                    drawingData: f.drawingData,
                    drawingBaseImage: baseForDrawing,
                    filterRaw: nil
                ))
            }
        }

        guard !pageInputs.isEmpty else { throw MergeError.failedToLoadPages }

        return try DocumentRepository.shared.saveDocument(
            kind: .scan,
            idTypeRaw: nil,
            rememberedFilterRaw: "original",
            pages: pageInputs
        )
    }
}
