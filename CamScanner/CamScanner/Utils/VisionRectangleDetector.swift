import CoreImage
import Foundation
import Vision

enum VisionRectangleDetector {
    private static func completeImageRequest(
        for request: VNImageRequestHandler,
        width: CGFloat,
        height: CGFloat,
        completion: @escaping ((Quadrilateral?) -> Void)
    ) {
        // Create the rectangle request, and, if found, return the biggest rectangle (else return nothing).
        let rectangleDetectionRequest: VNDetectRectanglesRequest = {
            let rectDetectRequest = VNDetectRectanglesRequest(completionHandler: { request, error in
                guard error == nil, let results = request.results as? [VNRectangleObservation], !results.isEmpty else {
                    completion(nil)
                    return
                }

                let quads: [Quadrilateral] = results.map(Quadrilateral.init)

                // This can't fail because the earlier guard protected against an empty array, but we use guard because of SwiftLint
                guard let biggest = quads.biggest() else {
                    completion(nil)
                    return
                }

                let transform = CGAffineTransform.identity
                    .scaledBy(x: width, y: height)

                completion(biggest.applying(transform))
            })

            rectDetectRequest.minimumConfidence = 0.35
            rectDetectRequest.maximumObservations = 8

            rectDetectRequest.minimumAspectRatio = 0.4
            rectDetectRequest.maximumAspectRatio = 3.0

            rectDetectRequest.quadratureTolerance = 30
            rectDetectRequest.minimumSize = 0.08

            rectDetectRequest.regionOfInterest = CGRect(
                x: 0.05,
                y: 0.1,
                width: 0.9,
                height: 0.8
            )
            
            rectDetectRequest.preferBackgroundProcessing = true
            rectDetectRequest.revision = VNDetectRectanglesRequest.supportedRevisions.max()!

            return rectDetectRequest
        }()

        // Send the requests to the request handler.
        do {
            try request.perform([rectangleDetectionRequest])
        } catch {
            completion(nil)
            return
        }

    }

    /// Detects rectangles from the given CVPixelBuffer/CVImageBuffer on iOS 11 and above.
    ///
    /// - Parameters:
    ///   - pixelBuffer: The pixelBuffer to detect rectangles on.
    ///   - completion: The biggest rectangle on the CVPixelBuffer
    static func rectangle(forPixelBuffer pixelBuffer: CVPixelBuffer, completion: @escaping ((Quadrilateral?) -> Void)) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let processed = ImagePreprocessor.enhance(ciImage)

        let handler = VNImageRequestHandler(
            ciImage: processed,
            options: [:]
        )

        VisionRectangleDetector.completeImageRequest(
            for: handler,
            width: processed.extent.width,
            height: processed.extent.height,
            completion: completion
        )
    }

    /// Detects rectangles from the given image on iOS 11 and above.
    ///
    /// - Parameters:
    ///   - image: The image to detect rectangles on.
    /// - Returns: The biggest rectangle detected on the image.
    static func rectangle(forImage image: CIImage, completion: @escaping ((Quadrilateral?) -> Void)) {
        let processedImage = ImagePreprocessor.enhance(image)

        let imageRequestHandler = VNImageRequestHandler(
            ciImage: processedImage,
            options: [:]
        )
        
        VisionRectangleDetector.completeImageRequest(
            for: imageRequestHandler, width: image.extent.width,
            height: image.extent.height, completion: completion)
    }

    static func rectangle(
        forImage image: CIImage,
        orientation: CGImagePropertyOrientation,
        completion: @escaping ((Quadrilateral?) -> Void)
    ) {
        let processed = ImagePreprocessor.enhance(image)
        let handler = VNImageRequestHandler(
            ciImage: processed,
            orientation: orientation,
            options: [:]
        )

        let orientedImage = processed.oriented(orientation)

        VisionRectangleDetector.completeImageRequest(
            for: handler,
            width: orientedImage.extent.width,
            height: orientedImage.extent.height,
            completion: completion
        )
    }
}

enum ImagePreprocessor {
    static func enhance(_ image: CIImage) -> CIImage {
        // grayscale
        let gray = CIFilter.colorControls()
        gray.inputImage = image
        gray.saturation = 0
        gray.contrast = 1.8
        gray.brightness = 0

        guard let grayImage = gray.outputImage else {
            return image
        }

        // blur
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = grayImage
        blur.radius = 1.3

        guard let blurred = blur.outputImage else {
            return grayImage
        }

        // edges
        let edges = CIFilter.edges()
        edges.inputImage = blurred
        edges.intensity = 1.2

        return edges.outputImage ?? blurred
    }
}


final class RectangleSmoother {

    private let historyLimit = 6
    private var history: [Quadrilateral] = []

    func smooth(_ quad: Quadrilateral?) -> Quadrilateral? {

        guard let quad else {
            history.removeAll()
            return nil
        }

        history.append(quad)

        if history.count > historyLimit {
            history.removeFirst()
        }

        return averageQuad()
    }

    private func averageQuad() -> Quadrilateral {

        let count = CGFloat(history.count)

        let topLeft = history.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.topLeft.x, y: $0.y + $1.topLeft.y)
        }

        let topRight = history.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.topRight.x, y: $0.y + $1.topRight.y)
        }

        let bottomRight = history.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.bottomRight.x, y: $0.y + $1.bottomRight.y)
        }

        let bottomLeft = history.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.bottomLeft.x, y: $0.y + $1.bottomLeft.y)
        }

        return Quadrilateral(
            topLeft: CGPoint(x: topLeft.x / count, y: topLeft.y / count),
            topRight: CGPoint(x: topRight.x / count, y: topRight.y / count),
            bottomRight: CGPoint(x: bottomRight.x / count, y: bottomRight.y / count),
            bottomLeft: CGPoint(x: bottomLeft.x / count, y: bottomLeft.y / count)
        )
    }
}
