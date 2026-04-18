import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class FilterRenderer {
    static let shared = FilterRenderer()
    private let context = CIContext(options: nil)
    private let openCVRenderer = OpenCVFilterRenderer()

    private init() {}

    // MARK: - Public

    func render(
        image: UIImage,
        state: FilterState
    ) -> UIImage? {
        if state.type == .blackWhite || state.type == .perfect || state.type == .inverted {
            return openCVRenderer.render(image: image, state: state)
        }
        
        guard var ciImage = normalizedCIImage(from: image) else {
            return image
        }

        if state.rotationAngle != 0 {
            ciImage = applyRotation(
                angle: state.rotationAngle,
                to: ciImage
            )
        }

        ciImage = applyFilter(
            type: state.type,
            adjustment: state.adjustment,
            to: ciImage
        )

        guard let cgImage = context.createCGImage(
            ciImage,
            from: ciImage.extent
        ) else {
            return image
        }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: .up
        )
    }

    // MARK: - Core Filter Switch

    private func applyFilter(
        type: DocumentFilterType,
        adjustment: CGFloat,
        to image: CIImage
    ) -> CIImage {

        switch type {

        case .original:
            return image

        case .auto:
            return autoEnhance(image, adjustment: adjustment)

        case .perfect:
            return perfectEnhance(image, adjustment: adjustment)

        case .blackWhite:
            return blackWhite(image, adjustment: adjustment)

        case .inverted:
            return inverted(image, adjustment: adjustment)
        }
    }

    // MARK: - Rotation

    private func applyRotation(
        angle: CGFloat,
        to image: CIImage
    ) -> CIImage {

        let transform = CGAffineTransform(rotationAngle: -angle)
        let rotated = image.transformed(by: transform)

        let originalExtent = image.extent
        let rotatedExtent = rotated.extent

        let dx = originalExtent.midX - rotatedExtent.midX
        let dy = originalExtent.midY - rotatedExtent.midY

        return rotated.transformed(
            by: CGAffineTransform(translationX: dx, y: dy)
        )
    }

    // MARK: - Normalize

    private func normalizedCIImage(from image: UIImage) -> CIImage? {

        guard let ci = CIImage(image: image) else { return nil }

        switch image.imageOrientation {
        case .up: return ci
        case .right: return ci.oriented(.right)
        case .left: return ci.oriented(.left)
        case .down: return ci.oriented(.down)
        case .upMirrored: return ci.oriented(.upMirrored)
        case .downMirrored: return ci.oriented(.downMirrored)
        case .leftMirrored: return ci.oriented(.leftMirrored)
        case .rightMirrored: return ci.oriented(.rightMirrored)
        @unknown default: return ci
        }
    }
}

// MARK: - Concrete Filters
private extension FilterRenderer {
    // MARK: - AUTO

    func autoEnhance(
        _ image: CIImage,
        adjustment: CGFloat
    ) -> CIImage {

        var output = image

        func apply(_ name: String,
                   _ configure: (CIFilter) -> Void = { _ in }) {

            guard let filter = CIFilter(name: name) else { return }
            filter.setValue(output, forKey: kCIInputImageKey)
            configure(filter)

            if let result = filter.outputImage {
                output = result
            }
        }

        apply("CIHighlightShadowAdjust") {
            $0.setValue(1.10 + adjustment * 0.4, forKey: "inputHighlightAmount")
            $0.setValue(-0.15 - adjustment * 0.3, forKey: "inputShadowAmount")
        }

        apply("CIColorControls") {
            $0.setValue(0.05 + adjustment * 0.2, forKey: kCIInputBrightnessKey)
            $0.setValue(1.15 + adjustment * 0.5, forKey: kCIInputContrastKey)
            $0.setValue(1.05, forKey: kCIInputSaturationKey)
        }

        apply("CIExposureAdjust") {
            $0.setValue(0.25 + adjustment * 0.8, forKey: kCIInputEVKey)
        }

        apply("CIVibrance") {
            $0.setValue(0.10 + adjustment * 0.4, forKey: "inputAmount")
        }

        apply("CISharpenLuminance") {
            $0.setValue(0.35 + adjustment * 0.5, forKey: kCIInputSharpnessKey)
        }

        return output
    }

    // MARK: - PERFECT

    func perfectEnhance(
        _ image: CIImage,
        adjustment: CGFloat
    ) -> CIImage {

        var output = image

        func apply(_ name: String,
                   _ configure: (CIFilter) -> Void = { _ in }) {

            guard let filter = CIFilter(name: name) else { return }
            filter.setValue(output, forKey: kCIInputImageKey)
            configure(filter)

            if let result = filter.outputImage {
                output = result
            }
        }

        apply("CIDocumentEnhancer")

        apply("CIColorControls") {
            $0.setValue(1.20 + adjustment * 0.8, forKey: kCIInputContrastKey)
            $0.setValue(1.10 + adjustment * 0.5, forKey: kCIInputSaturationKey)
        }

        apply("CIExposureAdjust") {
            $0.setValue(0.30 + adjustment * 0.6, forKey: kCIInputEVKey)
        }

        apply("CIGammaAdjust") {
            $0.setValue(0.95 - adjustment * 0.3, forKey: "inputPower")
        }

        apply("CISharpenLuminance") {
            $0.setValue(0.40 + adjustment * 0.6, forKey: kCIInputSharpnessKey)
        }

        return output
    }

    // MARK: - BLACK & WHITE

    func blackWhite(
        _ image: CIImage,
        adjustment: CGFloat
    ) -> CIImage {

        var output = image

        func apply(_ name: String,
                   _ configure: (CIFilter) -> Void = { _ in }) {

            guard let filter = CIFilter(name: name) else { return }
            filter.setValue(output, forKey: kCIInputImageKey)
            configure(filter)

            if let result = filter.outputImage {
                output = result
            }
        }

        apply("CIColorControls") {
            $0.setValue(0.30, forKey: kCIInputBrightnessKey)
            $0.setValue(4.00 + adjustment * 4.0, forKey: kCIInputContrastKey)
            $0.setValue(0.00, forKey: kCIInputSaturationKey)
        }

        apply("CIExposureAdjust") {
            $0.setValue(2.00 + adjustment * 1.5, forKey: kCIInputEVKey)
        }

        apply("CIGammaAdjust") {
            $0.setValue(0.01 + adjustment * 0.2, forKey: "inputPower")
        }

        return output
    }

    // MARK: - INVERTED

    func inverted(
        _ image: CIImage,
        adjustment: CGFloat
    ) -> CIImage {

        var output = image

        func apply(_ name: String,
                   _ configure: (CIFilter) -> Void = { _ in }) {

            guard let filter = CIFilter(name: name) else { return }
            filter.setValue(output, forKey: kCIInputImageKey)
            configure(filter)

            if let result = filter.outputImage {
                output = result
            }
        }

        apply("CIDocumentEnhancer")
        apply("CIColorInvert")

        apply("CIHighlightShadowAdjust") {
            $0.setValue(2.0 + adjustment * 0.5, forKey: "inputHighlightAmount")
            $0.setValue(0.5 + adjustment * 0.3, forKey: "inputShadowAmount")
        }

        apply("CIColorControls") {
            $0.setValue(-0.35 + adjustment * 0.6, forKey: kCIInputBrightnessKey)
            $0.setValue(1.1 + adjustment * 0.8, forKey: kCIInputContrastKey)
        }

        apply("CIGammaAdjust") {
            $0.setValue(1.8 + adjustment * 1.2, forKey: "inputPower")
        }

        apply("CISharpenLuminance") {
            $0.setValue(0.6 + adjustment * 0.6, forKey: kCIInputSharpnessKey)
        }

        return output
    }
}
