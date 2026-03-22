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

        guard let ciImage = CIImage(cvPixelBuffer: pixelBuffer) as CIImage?,
              let uiImage = ciImageToUIImage(ciImage) else {
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

    private static func detectLargestRectangle(in source: Mat, width: CGFloat, height: CGFloat) -> Quadrilateral? {
        let gray = Mat()
        if source.channels() == 4 {
            Imgproc.cvtColor(src: source, dst: gray, code: .COLOR_BGRA2GRAY)
        } else if source.channels() == 3 {
            Imgproc.cvtColor(src: source, dst: gray, code: .COLOR_BGR2GRAY)
        } else {
            source.copy(to: gray)
        }

        let blurred = Mat()
        Imgproc.GaussianBlur(
            src: gray,
            dst: blurred,
            ksize: Size2i(width: 5, height: 5),
            sigmaX: 0
        )

        let edges = Mat()
        Imgproc.Canny(image: blurred, edges: edges, threshold1: 50, threshold2: 200)

        // Dilate to close gaps in edges
        let kernel = Imgproc.getStructuringElement(
            shape: .MORPH_RECT,
            ksize: Size2i(width: 3, height: 3)
        )
        let dilated = Mat()
        Imgproc.dilate(src: edges, dst: dilated, kernel: kernel)

        var contours = [[Point2i]]()
        Imgproc.findContours(
            image: dilated,
            contours: &contours,
            hierarchy: Mat(),
            mode: .RETR_EXTERNAL,
            method: .CHAIN_APPROX_SIMPLE
        )

        let imageArea = Double(width * height)
        let minArea = imageArea * 0.05
        var bestQuad: Quadrilateral?
        var bestArea: Double = 0

        for contour in contours {
            let contourMat = Mat()
            let contourData = contour.map { Point2i(x: $0.x, y: $0.y) }
            // Convert [Point2i] to Mat for contourArea
            let pointsMat = MatOfPoint(array: contourData)

            let area = Imgproc.contourArea(contour: pointsMat)
            guard area > minArea else { continue }

            // Convert to Point2f for arcLength and approxPolyDP
            let contour2f: [Point2f] = contour.map { Point2f(x: Float($0.x), y: Float($0.y)) }

            let peri = Imgproc.arcLength(curve: contour2f, closed: true)
            var approx = [Point2f]()
            Imgproc.approxPolyDP(curve: contour2f, approxCurve: &approx, epsilon: 0.02 * peri, closed: true)

            guard approx.count == 4 else { continue }

            if area > bestArea {
                bestArea = area
                // OpenCV uses top-left origin; convert to bottom-left origin
                // so that the existing toCartesian() call in CaptureSessionManager works correctly.
                let h = height
                var quad = Quadrilateral(
                    topLeft: CGPoint(x: CGFloat(approx[0].x), y: h - CGFloat(approx[0].y)),
                    topRight: CGPoint(x: CGFloat(approx[1].x), y: h - CGFloat(approx[1].y)),
                    bottomRight: CGPoint(x: CGFloat(approx[2].x), y: h - CGFloat(approx[2].y)),
                    bottomLeft: CGPoint(x: CGFloat(approx[3].x), y: h - CGFloat(approx[3].y))
                )
                quad.reorganize()
                bestQuad = quad
            }
        }

        return bestQuad
    }
}
