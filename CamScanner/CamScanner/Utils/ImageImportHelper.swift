import UIKit
import PhotosUI
import SwiftUI

enum ImageImportHelper {
    static func loadImages(from items: [PhotosPickerItem]) async -> [UIImage] {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        return images
    }

    static func loadImages(from urls: [URL]) -> [UIImage] {
        var images: [UIImage] = []
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            if url.pathExtension.lowercased() == "pdf" {
                images.append(contentsOf: PDFImageExtractor.extractImages(from: url))
            } else if let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) {
                images.append(image)
            }
        }
        return images
    }

    static func makeCropperInputModel(from images: [UIImage]) -> ScanCropperInputModel {
        let frames = images.map { image -> CapturedFrame in
            let normalized = ensureScale1(image.normalizedUp())
            let preview = normalized.downscaled(maxDimension: 1200)
            return CapturedFrame(
                preview: preview,
                previewBase: preview,
                displayBase: preview,
                original: normalized
            )
        }

        let group = PreviewPageGroup(
            documentType: .documents,
            frames: frames
        )

        return ScanCropperInputModel(pageGroups: [group])
    }

    private static func ensureScale1(_ image: UIImage) -> UIImage {
        guard image.scale != 1 else { return image }
        let pixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: pixelSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }
}
