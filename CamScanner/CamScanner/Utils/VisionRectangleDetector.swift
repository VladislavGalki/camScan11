import CoreImage
import CoreVideo
import Foundation
import UIKit
import opencv2

enum VisionRectangleDetector {

    // MARK: - Public API

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

    static func rectangle(forImage image: CIImage, completion: @escaping ((Quadrilateral?) -> Void)) {
        guard let uiImage = ciImageToUIImage(image) else {
            completion(nil)
            return
        }
        let mat = Mat(uiImage: uiImage)
        let quad = detectLargestRectangle(in: mat, width: image.extent.width, height: image.extent.height)
        completion(quad)
    }

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

        var bestQuad: Quadrilateral?
        var bestArea: Double = 0
        let imageArea = Double(small.cols()) * Double(small.rows())
        let minArea = imageArea * 0.02

        let cannyLow = Mat()
        Imgproc.Canny(image: blurred, edges: cannyLow, threshold1: 30, threshold2: 100)
        morphAndFind(cannyLow, minArea: minArea, best: &bestQuad, bestArea: &bestArea)

        let cannyMed = Mat()
        Imgproc.Canny(image: blurred, edges: cannyMed, threshold1: 50, threshold2: 150)
        morphAndFind(cannyMed, minArea: minArea, best: &bestQuad, bestArea: &bestArea)

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

        guard var quad = bestQuad else {
            return nil
        }

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
            guard area > minArea else { continue }
            guard area > bestArea else { continue }

            let contour2f: [Point2f] = contour.map { Point2f(x: Float($0.x), y: Float($0.y)) }
            let peri = Imgproc.arcLength(curve: contour2f, closed: true)

            var approx = [Point2f]()
            Imgproc.approxPolyDP(curve: contour2f, approxCurve: &approx, epsilon: 0.02 * peri, closed: true)

            guard approx.count == 4 else { continue }
            guard isConvex(approx) else { continue }

            let imageArea = Double(dilated.cols()) * Double(dilated.rows())
            if area / imageArea > 0.90 {
                continue
            }

            guard hasReasonableAngles(approx) else { continue }
            guard hasReasonableAspectRatio(approx) else { continue }

            bestArea = area
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

    private static func hasReasonableAngles(_ points: [Point2f]) -> Bool {
        let minAngle: Double = 60
        let maxAngle: Double = 120

        for i in 0..<4 {
            let a = points[i]
            let b = points[(i + 1) % 4]
            let c = points[(i + 2) % 4]

            let v1x = Double(a.x - b.x)
            let v1y = Double(a.y - b.y)
            let v2x = Double(c.x - b.x)
            let v2y = Double(c.y - b.y)

            let dot = v1x * v2x + v1y * v2y
            let mag1 = sqrt(v1x * v1x + v1y * v1y)
            let mag2 = sqrt(v2x * v2x + v2y * v2y)
            guard mag1 > 0, mag2 > 0 else { return false }

            let cosAngle = max(-1, min(1, dot / (mag1 * mag2)))
            let angle = acos(cosAngle) * 180.0 / .pi

            if angle < minAngle || angle > maxAngle { return false }
        }
        return true
    }

    private static func hasReasonableAspectRatio(_ points: [Point2f]) -> Bool {
        func dist(_ a: Point2f, _ b: Point2f) -> Double {
            let dx = Double(a.x - b.x)
            let dy = Double(a.y - b.y)
            return sqrt(dx * dx + dy * dy)
        }
        let side1 = dist(points[0], points[1])
        let side2 = dist(points[1], points[2])
        guard side1 > 0, side2 > 0 else { return false }
        let ratio = max(side1, side2) / min(side1, side2)
        return ratio <= 5.0
    }

    private static func isConvex(_ points: [Point2f]) -> Bool {
        guard points.count == 4 else { return false }
        let cgPoints = points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }

        var positiveCount = 0
        var negativeCount = 0

        for i in 0..<4 {
            let a = cgPoints[i]
            let b = cgPoints[(i + 1) % 4]
            let c = cgPoints[(i + 2) % 4]

            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            if cross > 0 { positiveCount += 1 }
            else if cross < 0 { negativeCount += 1 }
        }

        return positiveCount == 0 || negativeCount == 0
    }
}
