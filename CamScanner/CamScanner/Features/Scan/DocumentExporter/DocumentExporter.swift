import UIKit
import Photos

final class DocumentExporter {

    init() {}

    enum ExportError: Error {
        case noImages
        case failedToWrite
        case photosNotAuthorized
    }

    // MARK: - Export

    func exportOrSave(
        images: [UIImage],
        format: DocumentExportFormat,
        fileName: String,
        completion: @escaping (Result<[URL], Error>) -> Void
    ) {
        let images = images.compactMap { $0 }
        guard !images.isEmpty else {
            completion(.failure(ExportError.noImages))
            return
        }

        switch format {
        case .jpeg, .png:
            saveToPhotos(images) { result in
                switch result {
                case .success:
                    completion(.success([]))
                case .failure(let err):
                    completion(.failure(err))
                }
            }

        default:
            do {
                let urls = try exportURLs(images: images, format: format, fileName: fileName)
                completion(.success(urls))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - URL export

    func exportURLs(images: [UIImage], format: DocumentExportFormat, fileName: String) throws -> [URL] {
        let images = images.compactMap { $0 }
        guard !images.isEmpty else { throw ExportError.noImages }

        let tempDir = FileManager.default.temporaryDirectory
        let safeName = fileName.replacingOccurrences(of: "/", with: "_")

        switch format {
        case .pdf:
            let url = tempDir.appendingPathComponent("\(safeName).pdf")
            try writePDF(images: images, to: url)
            return [url]

        case .jpeg:
            return try images.enumerated().map { idx, img in
                let suffix = images.count > 1 ? "_\(idx+1)" : ""
                let url = tempDir.appendingPathComponent("\(safeName)\(suffix).jpg")
                try writeJPEG(img, to: url, quality: 0.92)
                return url
            }

        case .png:
            return try images.enumerated().map { idx, img in
                let suffix = images.count > 1 ? "_\(idx+1)" : ""
                let url = tempDir.appendingPathComponent("\(safeName)\(suffix).png")
                try writePNG(img, to: url)
                return url
            }

        case .longImage:
            let stitched = stitchVertically(images: images)
            let url = tempDir.appendingPathComponent("\(safeName)_long.jpg")
            try writeJPEG(stitched, to: url, quality: 0.92)
            return [url]

        case .ppt, .word, .excel:
            let url = tempDir.appendingPathComponent("\(safeName).pdf")
            try writePDF(images: images, to: url)
            return [url]
        }
    }

    func export(images: [UIImage], format: DocumentExportFormat, fileName: String) throws -> URL {
        let urls = try exportURLs(images: images, format: format, fileName: fileName)
        guard let first = urls.first else { throw ExportError.failedToWrite }
        return first
    }

    // MARK: - Photos save

    private func saveToPhotos(_ images: [UIImage], completion: @escaping (Result<Void, Error>) -> Void) {

        func performSave() {
            PHPhotoLibrary.shared().performChanges({
                for img in images {
                    PHAssetChangeRequest.creationRequestForAsset(from: img)
                }
            }, completionHandler: { _, error in
                DispatchQueue.main.async {
                    if let error { completion(.failure(error)) }
                    else { completion(.success(())) }
                }
            })
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            performSave()

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        performSave()
                    } else {
                        completion(.failure(ExportError.photosNotAuthorized))
                    }
                }
            }

        default:
            completion(.failure(ExportError.photosNotAuthorized))
        }
    }

    // MARK: - PDF

    private func writePDF(images: [UIImage], to url: URL) throws {
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: .init(x: 0, y: 0, width: 612, height: 792), format: format)
        let data = renderer.pdfData { ctx in
            for img in images {
                ctx.beginPage()
                let pageRect = ctx.pdfContextBounds
                let targetRect = aspectFitRect(imageSize: img.size, in: pageRect.insetBy(dx: 24, dy: 24))
                img.draw(in: targetRect)
            }
        }

        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw ExportError.failedToWrite
        }
    }

    private func aspectFitRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: rect.midX - w/2, y: rect.midY - h/2, width: w, height: h)
    }

    // MARK: - JPEG/PNG

    private func writeJPEG(_ image: UIImage, to url: URL, quality: CGFloat) throws {
        guard let data = image.jpegData(compressionQuality: quality) else { throw ExportError.failedToWrite }
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw ExportError.failedToWrite
        }
    }

    private func writePNG(_ image: UIImage, to url: URL) throws {
        guard let data = image.pngData() else { throw ExportError.failedToWrite }
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw ExportError.failedToWrite
        }
    }

    // MARK: - Long image (stitch)

    private func stitchVertically(images: [UIImage]) -> UIImage {
        let targetWidth = images.first?.size.width ?? 1000

        let scaledSizes: [CGSize] = images.map { img in
            let scale = targetWidth / max(1, img.size.width)
            return CGSize(width: targetWidth, height: img.size.height * scale)
        }

        let totalHeight = scaledSizes.reduce(0) { $0 + $1.height }

        let format = UIGraphicsImageRendererFormat()
        format.scale = images.first?.scale ?? UIScreen.main.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetWidth, height: totalHeight), format: format)
        return renderer.image { _ in
            var y: CGFloat = 0
            for (idx, img) in images.enumerated() {
                let size = scaledSizes[idx]
                img.draw(in: CGRect(x: 0, y: y, width: size.width, height: size.height))
                y += size.height
            }
        }
    }
}
