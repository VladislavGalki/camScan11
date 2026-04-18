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

        var pageInputs: [DocumentRepositoryOLD.PageInput] = []

        for docID in docIDs {
            let frames = try DocumentRepositoryOLD.shared.loadFrames(docID: docID)
            guard !frames.isEmpty else { continue }

            for f in frames {
                guard let display = f.preview, let full = f.original else { continue }

                let baseForDrawing: UIImage? = {
                    if let b = f.drawingBase { return b }
                    if f.drawingData != nil { return full }
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

        return try DocumentRepositoryOLD.shared.saveDocument(
            kind: .scan,
            idTypeRaw: nil,
            rememberedFilterRaw: "original",
            pages: pageInputs
        )
    }
}
