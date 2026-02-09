import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class FilterRenderer {
    static let shared = FilterRenderer()
    private let context = CIContext(options: nil)

    private init() {}

    // MARK: - Public

    func render(
        image: UIImage,
        state: FilterState
    ) -> UIImage? {
        logImage(image, tag: "RENDER INPUT")
        guard var ciImage = normalizedCIImage(from: image) else {
            return image
        }
        print("CI extent BEFORE:", ciImage.extent)

        if state.rotationAngle != 0 {
            ciImage = applyRotation(
                angle: state.rotationAngle,
                to: ciImage
            )
        }

        ciImage = applyFilter(
            type: state.type,
            to: ciImage
        )

        ciImage = applyBrightness(
            state.brightness,
            to: ciImage
        )

        print("CI extent AFTER:", ciImage.extent)
        guard let cgImage = context.createCGImage(
            ciImage,
            from: ciImage.extent
        ) else {
            return image
        }

        let result = UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: .up
        )

        logImage(result, tag: "RENDER OUTPUT")
        return result
    }
    
    func applyRotation(
        angle: CGFloat,
        to image: CIImage
    ) -> CIImage {
        let transform = CGAffineTransform(rotationAngle: angle)
        let rotated = image.transformed(by: transform)
        let originalExtent = image.extent
        let rotatedExtent = rotated.extent

        let dx = originalExtent.midX - rotatedExtent.midX
        let dy = originalExtent.midY - rotatedExtent.midY

        return rotated.transformed(
            by: CGAffineTransform(translationX: dx, y: dy)
        )
    }
}

// MARK: - Filters

private extension FilterRenderer {
    func applyFilter(
        type: DocumentFilterType,
        to image: CIImage
    ) -> CIImage {
        switch type {
        case .original:
            return image
        case .auto:
            return autoEnhance(image)
        case .perfect:
            return perfectEnhance(image)
        case .blackWhite:
            return blackWhite(image)
        case .inverted:
            return inverted(image)
        }
    }

    func applyBrightness(
        _ value: CGFloat,
        to image: CIImage
    ) -> CIImage {

        guard value != 0 else { return image }

        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = Float(value)

        return filter.outputImage ?? image
    }
    
    func normalizedCIImage(from image: UIImage) -> CIImage? {
        guard let ci = CIImage(image: image) else { return nil }
        
        switch image.imageOrientation {
        case .up:
            return ci
        case .right:
            return ci.oriented(.right)
        case .left:
            return ci.oriented(.left)
        case .down:
            return ci.oriented(.down)
        case .upMirrored:
            return ci.oriented(.upMirrored)
        case .downMirrored:
            return ci.oriented(.downMirrored)
        case .leftMirrored:
            return ci.oriented(.leftMirrored)
        case .rightMirrored:
            return ci.oriented(.rightMirrored)
        @unknown default:
            return ci
        }
    }
}

// MARK: - Concrete Filters
private extension FilterRenderer {
    func autoEnhance(_ image: CIImage) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.contrast = 1.1
        filter.saturation = 1.05
        return filter.outputImage ?? image
    }

    func perfectEnhance(_ image: CIImage) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.contrast = 1.25
        filter.brightness = 0.03
        filter.saturation = 1.1
        return filter.outputImage ?? image
    }

    func blackWhite(_ image: CIImage) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = 0
        return filter.outputImage ?? image
    }

    func inverted(_ image: CIImage) -> CIImage {
        let filter = CIFilter.colorInvert()
        filter.inputImage = image
        return filter.outputImage ?? image
    }
}

// MARK: - Debug

func logImage(_ image: UIImage?, tag: String) {
    guard let image else {
        print("❌ \(tag) image nil")
        return
    }

    print("""
    🖼 \(tag)
       size: \(image.size)
       scale: \(image.scale)
       orientation: \(image.imageOrientation.rawValue)
    """)
}
