import UIKit

final class ImageCompressionService {
    static let shared = ImageCompressionService()

    private init() {}

    func compress(
        _ image: UIImage,
        maxDimension: CGFloat = 2480,
        quality: CGFloat = 0.72
    ) -> UIImage {

        let maxSide = max(image.size.width, image.size.height)

        guard maxSide > maxDimension else {
            return image
        }

        let scale = maxDimension / maxSide

        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(
            size: newSize,
            format: {
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                format.opaque = true
                return format
            }()
        )

        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        guard let data = resized.jpegData(compressionQuality: quality),
              let compressed = UIImage(data: data)
        else {
            return resized
        }

        return compressed
    }
}
