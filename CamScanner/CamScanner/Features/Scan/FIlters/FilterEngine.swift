import UIKit
import CoreImage

final class FilterEngine {

    static let shared = FilterEngine()

    private let context: CIContext

    private init() {
        self.context = CIContext(options: [
            .useSoftwareRenderer: false
        ])
    }

    // MARK: - Public

    func apply(_ filter: PreviewFilter, to image: UIImage) -> UIImage {
        if filter == .omnifix {
            return image
        }

        guard let ci = CIImage(image: image) else { return image }

        let out: CIImage
        switch filter {
        case .original:
            out = ci

        case .invert:
            out = ci.applyingFilter("CIColorInvert")

        case .grayscale:
            out = ci.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.05,
                kCIInputBrightnessKey: 0.0
            ])

        case .brighter:
            out = ci
                .applyingFilter("CIExposureAdjust", parameters: [
                    kCIInputEVKey: 0.35
                ])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.06,
                    kCIInputBrightnessKey: 0.02,
                    kCIInputSaturationKey: 1.0
                ])

        case .enhance:
            out = ci
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.25,
                    kCIInputBrightnessKey: 0.02,
                    kCIInputSaturationKey: 0.95
                ])
                .applyingFilter("CISharpenLuminance", parameters: [
                    kCIInputSharpnessKey: 0.55
                ])

        case .eco:
            out = ci
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.08,
                    kCIInputBrightnessKey: 0.01,
                    kCIInputSaturationKey: 0.90
                ])
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 7200, y: 0)
                ])

        case .noShadow:
            out = ci
                .applyingFilter("CIHighlightShadowAdjust", parameters: [
                    "inputShadowAmount": 1.00,
                    "inputHighlightAmount": 0.25
                ])
                .applyingFilter("CIExposureAdjust", parameters: [
                    kCIInputEVKey: 0.15
                ])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.10,
                    kCIInputBrightnessKey: 0.01,
                    kCIInputSaturationKey: 0.95
                ])

        case .noHandwriting:
            out = ci
                .applyingFilter("CINoiseReduction", parameters: [
                    "inputNoiseLevel": 0.02,
                    "inputSharpness": 0.40
                ])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.35,
                    kCIInputContrastKey: 1.35,
                    kCIInputBrightnessKey: 0.02
                ])
                .applyingFilter("CISharpenLuminance", parameters: [
                    kCIInputSharpnessKey: 0.70
                ])

        case .blackWhite:
            let pre = ci
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 1.35,
                    kCIInputBrightnessKey: 0.03
                ])
                .applyingFilter("CISharpenLuminance", parameters: [
                    kCIInputSharpnessKey: 0.40
                ])

            out = threshold(pre, t: 0.62)
        case .omnifix:
            out = ci
        }

        return render(out, like: image) ?? image
    }

    // MARK: - Rendering

    private func render(_ ci: CIImage, like image: UIImage) -> UIImage? {
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }

    // MARK: - Threshold kernel

    private lazy var thresholdKernel: CIColorKernel? = {
        let src = """
        kernel vec4 thresholdFilter(__sample s, float t) {
            float l = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
            float v = step(t, l);
            return vec4(vec3(v), 1.0);
        }
        """
        return CIColorKernel(source: src)
    }()

    private func threshold(_ input: CIImage, t: Float) -> CIImage {
        guard let k = thresholdKernel else { return input }
        return k.apply(extent: input.extent, arguments: [input, t]) ?? input
    }
}
