import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO

/// Post-capture processing:
/// 1) Preprocess image for stronger edges/contrast
/// 2) Detect document rectangle on a single photo (2-pass Vision rectangles)
/// 3) Perspective-correct using CoreImage (CIPerspectiveCorrection)
final class DocumentScanProcessor {

    enum ScanError: Error {
        case noCGImage
        case noRectangleFound
        case perspectiveFailed
    }

    private let ciContext = CIContext()

    // MARK: - Public API

    /// Main entry
    func makeScan(from image: UIImage) async throws -> UIImage {
        // Normalize to .up to simplify coordinate mapping
        let normalized = image.normalizedToUpOrientation()
        guard let cg = normalized.cgImage else { throw ScanError.noCGImage }

        // Preprocess (helps on shadows / strong perspective / low-contrast tables)
        let visionCG = preprocessedCGImage(from: cg) ?? cg

        // 2-pass detection: strict -> relaxed
        let rect = try detectBestRectangle(in: visionCG)

        // Convert VNRectangleObservation points (normalized, bottom-left origin)
        // into pixel coords (top-left origin) for our perspective helper
        let quadPxTopLeft = quadPixelsTopLeft(from: rect, imageWidth: visionCG.width, imageHeight: visionCG.height)

        guard let out = perspectiveCorrect(ciBaseImage: CIImage(cgImage: cg), // use original for max quality
                                           quadPxTopLeft: quadPxTopLeft,
                                           baseImageSize: CGSize(width: visionCG.width, height: visionCG.height)) else {
            throw ScanError.perspectiveFailed
        }

        return out
    }

    // MARK: - Preprocess for Vision

    /// Improves rectangle detection under hard shadows / skew by increasing contrast & edge clarity.
    private func preprocessedCGImage(from cg: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cg)

        let color = CIFilter.colorControls()
        color.inputImage = input
        color.saturation = 0
        color.contrast = 1.25
        color.brightness = 0.02

        let sharp = CIFilter.sharpenLuminance()
        sharp.inputImage = color.outputImage
        sharp.sharpness = 0.40

        guard let out = sharp.outputImage else { return nil }
        return ciContext.createCGImage(out, from: out.extent)
    }

    // MARK: - Vision detect (2-pass)

    private struct DetectConfig {
        var maxObs: Int
        var minConfidence: VNConfidence
        var minSize: Float
        var quadTol: Int
        var roi: CGRect
    }

    private func detectBestRectangle(in cgImage: CGImage) throws -> VNRectangleObservation {

        let strict = DetectConfig(
            maxObs: 12,
            minConfidence: 0.55,
            minSize: 0.15,
            quadTol: 20,
            roi: CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90)
        )

        if let best = try detectAndPickBest(cgImage: cgImage, cfg: strict) {
            return best
        }

        // Relaxed pass for strong perspective / low confidence edges
        let relaxed = DetectConfig(
            maxObs: 30,
            minConfidence: 0.35,
            minSize: 0.08,
            quadTol: 45,
            roi: CGRect(x: 0.02, y: 0.02, width: 0.96, height: 0.96)
        )

        if let best = try detectAndPickBest(cgImage: cgImage, cfg: relaxed) {
            return best
        }

        throw ScanError.noRectangleFound
    }

    private func detectAndPickBest(cgImage: CGImage, cfg: DetectConfig) throws -> VNRectangleObservation? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = cfg.maxObs
        request.minimumConfidence = cfg.minConfidence
        request.minimumSize = cfg.minSize
        request.quadratureTolerance = VNDegrees(cfg.quadTol)
        request.regionOfInterest = cfg.roi

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])

        guard let results = request.results, !results.isEmpty else { return nil }
        return pickBest(results)
    }

    // MARK: - Candidate scoring (SwiftScan-like)

    /// Choose best candidate:
    /// - prefer large rectangles
    /// - prefer near center
    /// - prefer document-like aspect ratio (approx by bbox)
    private func pickBest(_ obs: [VNRectangleObservation]) -> VNRectangleObservation? {
        let center = CGPoint(x: 0.5, y: 0.5)

        var bestScore: CGFloat = -1
        var best: VNRectangleObservation?

        for o in obs {
            let bb = o.boundingBox
            let area = bb.width * bb.height
            guard area > 0.08 else { continue } // allow more in relaxed mode

            // bbox aspect ratio heuristic
            let w = bb.width, h = bb.height
            guard w > 0, h > 0 else { continue }

            // Documents can be portrait or landscape; accept wider range
            let aspect = h / w
            guard aspect >= 0.55, aspect <= 3.0 else { continue }

            // center distance (bbox center)
            let cVision = CGPoint(x: bb.midX, y: bb.midY)               // bottom-left origin
            let cTopLeft = CGPoint(x: cVision.x, y: 1 - cVision.y)
            let dx = cTopLeft.x - center.x
            let dy = cTopLeft.y - center.y
            let dist = sqrt(dx*dx + dy*dy)

            let conf = CGFloat(o.confidence)
            let centerFactor = max(0.15, 1.0 - dist * 1.2)

            // Score: area dominates, confidence helps, center helps.
            let score = area * (0.62 + 0.38 * conf) * centerFactor

            if score > bestScore {
                bestScore = score
                best = o
            }
        }

        return best
    }

    // MARK: - Mapping points

    /// Returns quad in pixel coordinates with TOP-LEFT origin.
    /// Order: [tl, tr, br, bl]
    private func quadPixelsTopLeft(from rect: VNRectangleObservation,
                                   imageWidth: Int,
                                   imageHeight: Int) -> [CGPoint] {

        let w = CGFloat(imageWidth)
        let h = CGFloat(imageHeight)

        // VNRectangleObservation points are normalized in image space with origin bottom-left.
        // Convert to pixel coords with top-left origin:
        // x_px = x * w
        // y_px_topLeft = (1 - y) * h
        func toPxTopLeft(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * w, y: (1 - p.y) * h)
        }

        return [
            toPxTopLeft(rect.topLeft),
            toPxTopLeft(rect.topRight),
            toPxTopLeft(rect.bottomRight),
            toPxTopLeft(rect.bottomLeft)
        ]
    }

    // MARK: - Perspective correction

    /// Apply perspective correction on a base CIImage (original-quality image),
    /// using quad points computed on `visionCG` resolution.
    private func perspectiveCorrect(ciBaseImage: CIImage,
                                    quadPxTopLeft: [CGPoint],
                                    baseImageSize visionSize: CGSize) -> UIImage? {
        guard quadPxTopLeft.count == 4 else { return nil }

        let baseExtent = ciBaseImage.extent
        guard baseExtent.width > 0, baseExtent.height > 0 else { return nil }

        // If Vision ran on a preprocessed image with different size (unlikely here),
        // map quad coordinates from visionSize -> baseExtent size.
        let sx = baseExtent.width / visionSize.width
        let sy = baseExtent.height / visionSize.height

        func scaleToBase(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * sx, y: p.y * sy)
        }

        let quadScaledTopLeft = quadPxTopLeft.map(scaleToBase)

        // CI coordinate system: origin bottom-left
        let H = baseExtent.height
        func toCICoords(_ pTopLeft: CGPoint) -> CGPoint {
            CGPoint(x: pTopLeft.x, y: H - pTopLeft.y)
        }

        let tl = toCICoords(quadScaledTopLeft[0])
        let tr = toCICoords(quadScaledTopLeft[1])
        let br = toCICoords(quadScaledTopLeft[2])
        let bl = toCICoords(quadScaledTopLeft[3])

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciBaseImage
        filter.topLeft = tl
        filter.topRight = tr
        filter.bottomRight = br
        filter.bottomLeft = bl

        guard let outputCI = filter.outputImage else { return nil }
        guard let outCG = ciContext.createCGImage(outputCI, from: outputCI.extent) else { return nil }

        return UIImage(cgImage: outCG, scale: 1, orientation: .up)
    }
}

// MARK: - UIImage helper

private extension UIImage {
    func normalizedToUpOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
