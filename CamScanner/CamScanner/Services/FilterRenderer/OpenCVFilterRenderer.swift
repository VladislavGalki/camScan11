import Foundation
import UIKit
import opencv2

final class OpenCVFilterRenderer {
    func render(image: UIImage, state: FilterState) -> UIImage? {
        let source = Mat(uiImage: image)
        let rotated = rotateMatIfNeeded(source, angle: state.rotationAngle)

        switch state.type {
        case .blackWhite:
            return renderBlackWhite(
                source: rotated,
                adjustment: state.adjustment
            )

        case .perfect:
            return renderPerfect(source: rotated)

        case .inverted:
            return renderInverted(
                source: rotated,
                adjustment: state.adjustment
            )

        default:
            return image
        }
    }
}

private extension OpenCVFilterRenderer {
    func renderBlackWhite(
        source: Mat,
        adjustment: CGFloat
    ) -> UIImage? {
        let gray = toGray(source)
        let normalized = removeShadows(from: gray, sigmaX: 2.5)

        let claheOutput = Mat()
        let clahe = Imgproc.createCLAHE(
            clipLimit: 5.0,
            tileGridSize: Size2i(width: 8, height: 8)
        )
        clahe.apply(src: normalized, dst: claheOutput)

        let contrasted = Mat()
        let alpha = max(0.6, Double(adjustment))
        let beta = -2.05

        claheOutput.convert(
            to: contrasted,
            rtype: CvType.CV_8U,
            alpha: alpha,
            beta: beta
        )

        let binary = Mat()
        let thresholdType = ThresholdTypes(
            rawValue:
                ThresholdTypes.THRESH_BINARY.rawValue |
                ThresholdTypes.THRESH_OTSU.rawValue
        )!

        Imgproc.threshold(
            src: contrasted,
            dst: binary,
            thresh: 0,
            maxval: 255,
            type: thresholdType
        )

        let cleaned = cleanupBorders(
            from: binary,
            inset: 20
        )

        return cleaned.toUIImage()
    }

    func renderInverted(
        source: Mat,
        adjustment: CGFloat
    ) -> UIImage? {
        let gray = toGray(source)
        let normalized = removeShadows(from: gray, sigmaX: 27)

        let claheOutput = Mat()
        let clahe = Imgproc.createCLAHE(
            clipLimit: 2.2,
            tileGridSize: Size2i(width: 8, height: 8)
        )
        clahe.apply(src: normalized, dst: claheOutput)

        let enhanced = Mat()
        let alpha = 1.1 + Double(adjustment) * 0.8
        let beta = -6.0 + Double(adjustment) * 10.0
        claheOutput.convert(
            to: enhanced,
            rtype: CvType.CV_8U,
            alpha: alpha,
            beta: beta
        )

        let sharpened = Mat()
        let kernel = Mat(rows: 3, cols: 3, type: CvType.CV_32F)
        try? kernel.put(row: 0, col: 0, data: [
            Float(0), Float(-0.5), Float(0),
            Float(-0.5), Float(3.0), Float(-0.5),
            Float(0), Float(-0.5), Float(0)
        ])
        Imgproc.filter2D(
            src: enhanced,
            dst: sharpened,
            ddepth: -1,
            kernel: kernel
        )

        let inverted = Mat()
        Core.bitwise_not(src: sharpened, dst: inverted)

        let adjusted = Mat()
        let gamma = 1.8 + Double(adjustment) * 1.2
        let lut = buildGammaLUT(gamma: gamma)
        Core.LUT(src: inverted, lut: lut, dst: adjusted)

        return adjusted.toUIImage()
    }

    func renderPerfect(source: Mat) -> UIImage? {
        let gray = toGray(source)
        let normalized = removeShadows(from: gray, sigmaX: 31)

        let claheOutput = Mat()
        let clahe = Imgproc.createCLAHE(
            clipLimit: 2.2,
            tileGridSize: Size2i(width: 8, height: 8)
        )
        clahe.apply(src: normalized, dst: claheOutput)

        let smoothed = Mat()
        Imgproc.GaussianBlur(
            src: claheOutput,
            dst: smoothed,
            ksize: Size2i(width: 3, height: 3),
            sigmaX: 0
        )

        let enhanced = Mat()
        smoothed.convert(
            to: enhanced,
            rtype: CvType.CV_8U,
            alpha: 1.12,
            beta: -6.0
        )

        let sharpened = Mat()
        let kernel = Mat(rows: 3, cols: 3, type: CvType.CV_32F)

        try? kernel.put(row: 0, col: 0, data: [
            Float(0), Float(-0.7), Float(0),
            Float(-0.7), Float(3.8), Float(-0.7),
            Float(0), Float(-0.7), Float(0)
        ])

        Imgproc.filter2D(
            src: enhanced,
            dst: sharpened,
            ddepth: -1,
            kernel: kernel
        )

        return sharpened.toUIImage()
    }

    func toGray(_ source: Mat) -> Mat {
        let gray = Mat()

        if source.channels() == 4 {
            Imgproc.cvtColor(src: source, dst: gray, code: .COLOR_RGBA2GRAY)
        } else if source.channels() == 3 {
            Imgproc.cvtColor(src: source, dst: gray, code: .COLOR_RGB2GRAY)
        } else {
            source.copy(to: gray)
        }

        return gray
    }

    func removeShadows(
        from gray: Mat,
        sigmaX: Double
    ) -> Mat {
        let background = Mat()
        Imgproc.GaussianBlur(
            src: gray,
            dst: background,
            ksize: Size2i(width: 0, height: 0),
            sigmaX: sigmaX
        )

        let grayFloat = Mat()
        let backgroundFloat = Mat()

        gray.convert(to: grayFloat, rtype: CvType.CV_32F)
        background.convert(to: backgroundFloat, rtype: CvType.CV_32F)

        let normalizedFloat = Mat()
        Core.divide(
            src1: grayFloat,
            src2: backgroundFloat,
            dst: normalizedFloat,
            scale: 255.0
        )

        let normalized = Mat()
        normalizedFloat.convert(to: normalized, rtype: CvType.CV_8U)

        return normalized
    }

    func cleanupBorders(
        from binary: Mat,
        inset: Int
    ) -> Mat {
        let result = Mat()
        binary.copy(to: result)

        let width = Int(result.cols())
        let height = Int(result.rows())
        let safeInset = max(0, min(inset, min(width, height) / 8))

        guard safeInset > 0 else { return result }

        Imgproc.rectangle(
            img: result,
            pt1: Point(x: 0, y: 0),
            pt2: Point(x: Int32(width), y: Int32(safeInset)),
            color: Scalar(255, 255, 255, 255),
            thickness: -1
        )

        Imgproc.rectangle(
            img: result,
            pt1: Point(x: 0, y: Int32(height - safeInset)),
            pt2: Point(x: Int32(width), y: Int32(height)),
            color: Scalar(255, 255, 255, 255),
            thickness: -1
        )

        Imgproc.rectangle(
            img: result,
            pt1: Point(x: 0, y: 0),
            pt2: Point(x: Int32(safeInset), y: Int32(height)),
            color: Scalar(255, 255, 255, 255),
            thickness: -1
        )

        Imgproc.rectangle(
            img: result,
            pt1: Point(x: Int32(width - safeInset), y: 0),
            pt2: Point(x: Int32(width), y: Int32(height)),
            color: Scalar(255, 255, 255, 255),
            thickness: -1
        )

        return result
    }

    func buildGammaLUT(gamma: Double) -> Mat {
        let lut = Mat(rows: 1, cols: 256, type: CvType.CV_8U)
        let invGamma = 1.0 / gamma
        var table = [UInt8](repeating: 0, count: 256)
        for i in 0..<256 {
            table[i] = UInt8(
                min(255, max(0, pow(Double(i) / 255.0, invGamma) * 255.0))
            )
        }
        try? lut.put(row: 0, col: 0, data: table)
        return lut
    }

    func rotateMatIfNeeded(_ source: Mat, angle: CGFloat) -> Mat {
        let degrees = Int((angle * 180 / .pi).rounded())
        let normalized = ((degrees % 360) + 360) % 360

        guard normalized != 0 else { return source }

        let result = Mat()

        switch normalized {
        case 90:
            Core.rotate(src: source, dst: result, rotateCode: .ROTATE_90_CLOCKWISE)
        case 180:
            Core.rotate(src: source, dst: result, rotateCode: .ROTATE_180)
        case 270:
            Core.rotate(src: source, dst: result, rotateCode: .ROTATE_90_COUNTERCLOCKWISE)
        default:
            return source
        }

        return result
    }
}
