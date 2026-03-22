import CoreImage
import CoreVideo
import Foundation
import UIKit
import opencv2

enum VisionRectangleDetector {

    // MARK: - Public API

    /// Detects the largest rectangle from a CVPixelBuffer.
    static func rectangle(forPixelBuffer pixelBuffer: CVPixelBuffer, completion: @escaping ((Quadrilateral?) -> Void)) {
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let uiImage = ciImageToUIImage(ciImage) else {
            completion(nil)
            return
        }

        let mat = Mat(uiImage: uiImage)
        let quad = detectLargestRectangle(in: mat, width: width, height: height)
        completion(quad)
    }

    /// Detects the largest rectangle from a CIImage.
    static func rectangle(forImage image: CIImage, completion: @escaping ((Quadrilateral?) -> Void)) {
        guard let uiImage = ciImageToUIImage(image) else {
            completion(nil)
            return
        }
        let mat = Mat(uiImage: uiImage)
        let quad = detectLargestRectangle(in: mat, width: image.extent.width, height: image.extent.height)
        completion(quad)
    }

    /// Detects the largest rectangle from a CIImage with orientation.
    static func rectangle(
        forImage image: CIImage,
        orientation: CGImagePropertyOrientation,
        completion: @escaping ((Quadrilateral?) -> Void)
    ) {
        let orientedImage = image.oriented(orientation)
        guard let uiImage = ciImageToUIImage(orientedImage) else {
            completion(nil)
            return
        }
        let mat = Mat(uiImage: uiImage)
        let quad = detectLargestRectangle(in: mat, width: orientedImage.extent.width, height: orientedImage.extent.height)
        completion(quad)
    }

    // MARK: - Private

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private static func ciImageToUIImage(_ ciImage: CIImage) -> UIImage? {
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Downscale for faster processing, returns scale factor.
    private static func downscale(_ source: Mat, maxDimension: Double = 640) -> (Mat, Double) {
        let maxSide = Double(max(source.cols(), source.rows()))
        guard maxSide > maxDimension else { return (source, 1.0) }

        let scale = maxDimension / maxSide
        let resized = Mat()
        Imgproc.resize(
            src: source,
            dst: resized,
            dsize: Size2i(
                width: Int32(Double(source.cols()) * scale),
                height: Int32(Double(source.rows()) * scale)
            )
        )
        return (resized, scale)
    }

    private static func detectLargestRectangle(in source: Mat, width: CGFloat, height: CGFloat) -> Quadrilateral? {
        let (small, scale) = downscale(source)

        let gray = Mat()
        if small.channels() == 4 {
            Imgproc.cvtColor(src: small, dst: gray, code: .COLOR_RGBA2GRAY)
        } else if small.channels() == 3 {
            Imgproc.cvtColor(src: small, dst: gray, code: .COLOR_RGB2GRAY)
        } else {
            small.copy(to: gray)
        }

        let blurred = Mat()
        Imgproc.GaussianBlur(
            src: gray,
            dst: blurred,
            ksize: Size2i(width: 5, height: 5),
            sigmaX: 1.5
        )

        // Try multiple edge detection strategies and pick the best result
        var bestQuad: Quadrilateral?
        var bestArea: Double = 0
        let imageArea = Double(small.cols()) * Double(small.rows())
        let minArea = imageArea * 0.02

        // Strategy 1: Canny with low thresholds
        let cannyLow = Mat()
        Imgproc.Canny(image: blurred, edges: cannyLow, threshold1: 30, threshold2: 100)
        morphAndFind(cannyLow, minArea: minArea, best: &bestQuad, bestArea: &bestArea)

        // Strategy 2: Canny with medium thresholds
        let cannyMed = Mat()
        Imgproc.Canny(image: blurred, edges: cannyMed, threshold1: 50, threshold2: 150)
        morphAndFind(cannyMed, minArea: minArea, best: &bestQuad, bestArea: &bestArea)

        // Strategy 3: Adaptive threshold + morphological close
        let adaptive = Mat()
        Imgproc.adaptiveThreshold(
            src: blurred,
            dst: adaptive,
            maxValue: 255,
            adaptiveMethod: .ADAPTIVE_THRESH_GAUSSIAN_C,
            thresholdType: .THRESH_BINARY_INV,
            blockSize: 11,
            C: 2
        )
        morphAndFind(adaptive, minArea: minArea, best: &bestQuad, bestArea: &bestArea)

        guard var quad = bestQuad else { return nil }

        // Scale coordinates back to original size
        if scale != 1.0 {
            let invScale = 1.0 / scale
            quad = Quadrilateral(
                topLeft: CGPoint(x: quad.topLeft.x * invScale, y: quad.topLeft.y * invScale),
                topRight: CGPoint(x: quad.topRight.x * invScale, y: quad.topRight.y * invScale),
                bottomRight: CGPoint(x: quad.bottomRight.x * invScale, y: quad.bottomRight.y * invScale),
                bottomLeft: CGPoint(x: quad.bottomLeft.x * invScale, y: quad.bottomLeft.y * invScale)
            )
        }

        return quad
    }

    /// Apply morphological close, find contours, and update best quad if a better one is found.
    private static func morphAndFind(
        _ edges: Mat,
        minArea: Double,
        best: inout Quadrilateral?,
        bestArea: inout Double
    ) {
        let kernel = Imgproc.getStructuringElement(
            shape: .MORPH_RECT,
            ksize: Size2i(width: 5, height: 5)
        )
        let closed = Mat()
        Imgproc.morphologyEx(src: edges, dst: closed, op: .MORPH_CLOSE, kernel: kernel)

        // Extra dilation to connect nearby edges
        let dilateKernel = Imgproc.getStructuringElement(
            shape: .MORPH_RECT,
            ksize: Size2i(width: 3, height: 3)
        )
        let dilated = Mat()
        Imgproc.dilate(src: closed, dst: dilated, kernel: dilateKernel)

        var contours = [[Point2i]]()
        Imgproc.findContours(
            image: dilated,
            contours: &contours,
            hierarchy: Mat(),
            mode: .RETR_LIST,
            method: .CHAIN_APPROX_SIMPLE
        )

        for contour in contours {
            let pointsMat = MatOfPoint(array: contour)
            let area = Imgproc.contourArea(contour: pointsMat)
            guard area > minArea, area > bestArea else { continue }

            let contour2f: [Point2f] = contour.map { Point2f(x: Float($0.x), y: Float($0.y)) }
            let peri = Imgproc.arcLength(curve: contour2f, closed: true)

            var approx = [Point2f]()
            Imgproc.approxPolyDP(curve: contour2f, approxCurve: &approx, epsilon: 0.02 * peri, closed: true)
            guard approx.count == 4, isConvex(approx) else { continue }

            bestArea = area
            // OpenCV uses top-left origin; convert to bottom-left origin
            // so that the existing toCartesian() call in CaptureSessionManager works correctly.
            let h = CGFloat(dilated.rows())
            var quad = Quadrilateral(
                topLeft: CGPoint(x: CGFloat(approx[0].x), y: h - CGFloat(approx[0].y)),
                topRight: CGPoint(x: CGFloat(approx[1].x), y: h - CGFloat(approx[1].y)),
                bottomRight: CGPoint(x: CGFloat(approx[2].x), y: h - CGFloat(approx[2].y)),
                bottomLeft: CGPoint(x: CGFloat(approx[3].x), y: h - CGFloat(approx[3].y))
            )
            quad.reorganize()
            best = quad
        }
    }

    private static func isConvex(_ points: [Point2f]) -> Bool {
        guard points.count == 4 else { return false }
        let cgPoints = points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }

        for i in 0..<4 {
            let a = cgPoints[i]
            let b = cgPoints[(i + 1) % 4]
            let c = cgPoints[(i + 2) % 4]

            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            if cross < 0 { return false }
        }
        return true
    }
}
