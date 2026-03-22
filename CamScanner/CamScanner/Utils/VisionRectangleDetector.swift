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
        print("[RectDetect] rectangle(forPixelBuffer:) called, size=\(width)x\(height)")

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let uiImage = ciImageToUIImage(ciImage) else {
            print("[RectDetect] ❌ ciImageToUIImage returned nil")
            completion(nil)
            return
        }

        let mat = Mat(uiImage: uiImage)
        print("[RectDetect] Mat created: \(mat.cols())x\(mat.rows()), channels=\(mat.channels()), type=\(mat.type())")
        let quad = detectLargestRectangle(in: mat, width: width, height: height)
        print("[RectDetect] result: \(quad != nil ? "FOUND quad" : "nil")")
        if let q = quad {
            print("[RectDetect]   tl=\(q.topLeft) tr=\(q.topRight) br=\(q.bottomRight) bl=\(q.bottomLeft)")
        }
        completion(quad)
    }

    /// Detects the largest rectangle from a CIImage.
    static func rectangle(forImage image: CIImage, completion: @escaping ((Quadrilateral?) -> Void)) {
        guard let uiImage = ciImageToUIImage(image) else {
            print("[RectDetect] ❌ ciImageToUIImage returned nil (forImage)")
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
            print("[RectDetect] ❌ ciImageToUIImage returned nil (forImage+orientation)")
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
        print("[RectDetect] downscaled \(source.cols())x\(source.rows()) -> \(resized.cols())x\(resized.rows()), scale=\(scale)")
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
        print("[RectDetect] gray: \(gray.cols())x\(gray.rows()), channels=\(gray.channels()), empty=\(gray.empty())")

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
        print("[RectDetect] imageArea=\(imageArea), minArea=\(minArea)")

        // Strategy 1: Canny with low thresholds
        let cannyLow = Mat()
        Imgproc.Canny(image: blurred, edges: cannyLow, threshold1: 30, threshold2: 100)
        let cannyLowNonZero = Core.countNonZero(src: cannyLow)
        print("[RectDetect] Strategy 1 (Canny low): nonZero=\(cannyLowNonZero)")
        morphAndFind(cannyLow, minArea: minArea, strategyName: "CannyLow", best: &bestQuad, bestArea: &bestArea)

        // Strategy 2: Canny with medium thresholds
        let cannyMed = Mat()
        Imgproc.Canny(image: blurred, edges: cannyMed, threshold1: 50, threshold2: 150)
        let cannyMedNonZero = Core.countNonZero(src: cannyMed)
        print("[RectDetect] Strategy 2 (Canny med): nonZero=\(cannyMedNonZero)")
        morphAndFind(cannyMed, minArea: minArea, strategyName: "CannyMed", best: &bestQuad, bestArea: &bestArea)

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
        let adaptiveNonZero = Core.countNonZero(src: adaptive)
        print("[RectDetect] Strategy 3 (Adaptive): nonZero=\(adaptiveNonZero)")
        morphAndFind(adaptive, minArea: minArea, strategyName: "Adaptive", best: &bestQuad, bestArea: &bestArea)

        guard var quad = bestQuad else {
            print("[RectDetect] ⚠️ No quad found across all strategies")
            return nil
        }

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
        strategyName: String,
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
        print("[RectDetect]   [\(strategyName)] contours found: \(contours.count)")

        var candidateCount = 0
        var passedAreaCount = 0
        var fourPointCount = 0
        var convexCount = 0

        for contour in contours {
            candidateCount += 1
            let pointsMat = MatOfPoint(array: contour)
            let area = Imgproc.contourArea(contour: pointsMat)
            guard area > minArea else { continue }
            passedAreaCount += 1
            guard area > bestArea else { continue }

            let contour2f: [Point2f] = contour.map { Point2f(x: Float($0.x), y: Float($0.y)) }
            let peri = Imgproc.arcLength(curve: contour2f, closed: true)

            var approx = [Point2f]()
            Imgproc.approxPolyDP(curve: contour2f, approxCurve: &approx, epsilon: 0.02 * peri, closed: true)

            if approx.count == 4 {
                fourPointCount += 1
            }
            guard approx.count == 4 else { continue }

            let convex = isConvex(approx)
            if convex { convexCount += 1 }
            guard convex else {
                print("[RectDetect]   [\(strategyName)] 4-point contour FAILED convex check, area=\(area)")
                continue
            }

            // Reject if contour covers >90% of the frame (it's the background, not a document)
            let imageArea = Double(dilated.cols()) * Double(dilated.rows())
            if area / imageArea > 0.90 {
                print("[RectDetect]   [\(strategyName)] REJECTED: covers \(Int(area / imageArea * 100))% of frame")
                continue
            }

            // Check angles are roughly rectangular (each corner within 30° of 90°)
            guard hasReasonableAngles(approx) else {
                print("[RectDetect]   [\(strategyName)] REJECTED: angles not rectangular, area=\(area)")
                continue
            }

            // Check aspect ratio is reasonable (not too extreme like 10:1)
            guard hasReasonableAspectRatio(approx) else {
                print("[RectDetect]   [\(strategyName)] REJECTED: extreme aspect ratio, area=\(area)")
                continue
            }

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
            print("[RectDetect]   [\(strategyName)] ✅ NEW best quad, area=\(area)")
        }
        print("[RectDetect]   [\(strategyName)] summary: total=\(candidateCount), passedArea=\(passedAreaCount), 4pt=\(fourPointCount), convex=\(convexCount)")
    }

    /// Check that all interior angles are within 30° of 90° (i.e. 60°–120°).
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

    /// Check aspect ratio is between 1:5 and 5:1.
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

        // Convex if all same sign (all CW or all CCW)
        return positiveCount == 0 || negativeCount == 0
    }
}
