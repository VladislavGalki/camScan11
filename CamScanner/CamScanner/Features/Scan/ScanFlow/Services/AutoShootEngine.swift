import UIKit
import CoreGraphics

final class AutoShootEngine {

    // MARK: - Tuning

    var minAreaEnter: CGFloat = 0.055
    var minAreaKeep: CGFloat  = 0.045

    var requiredStableFrames: CGFloat = 3

    var baseCenterShiftThreshold: CGFloat = 10

    var areaDeltaThreshold: CGFloat = 0.12

    var emaAlpha: CGFloat = 0.35

    var penaltyOnUnstable: CGFloat = 1.0
    var penaltyOnMissing: CGFloat = 1.5
    var penaltyOnNotQualified: CGFloat = 1.2

    var minShotInterval: CFTimeInterval = 1.2

    var isLoggingEnabled: Bool = true

    // MARK: - State

    private var isAreaQualified = false
    private var stableScore: CGFloat = 0
    private var lastAutoShotAt: CFTimeInterval = 0

    private var emaCenter: CGPoint?
    private var emaAreaRatio: CGFloat?

    // MARK: - Public API

    func update(
        enabled: Bool,
        canShoot: Bool,
        quad: Quadrilateral?,
        imageSize: CGSize
    ) -> AutoShootState {

        guard enabled else {
            softReset()
            return AutoShootState(isStable: false)
        }

        guard canShoot else {
            softReset()
            return AutoShootState(isStable: false)
        }

        guard var quad,
              imageSize.width > 0,
              imageSize.height > 0 else {

            applyPenalty(penaltyOnMissing)

            log(
                "missing quad -> penalty, score=\(fmt(stableScore))/\(fmt(requiredStableFrames))"
            )

            return AutoShootState(isStable: false)
        }

        quad.reorganize()

        // MARK: Area gate

        let frameArea =
            max(imageSize.width * imageSize.height, 1)

        let ratio =
            quadBoundingBoxArea(quad) / frameArea

        if !isAreaQualified {

            isAreaQualified =
                ratio >= minAreaEnter

        } else {

            if ratio < minAreaKeep {
                isAreaQualified = false
            }
        }

        log(
            "area ratio = \(fmt(ratio)) | qualified=\(isAreaQualified)"
        )

        guard isAreaQualified else {

            applyPenalty(penaltyOnNotQualified)

            return AutoShootState(
                isStable: false
            )
        }

        // MARK: EMA

        let center =
            quadCenter(quad)

        let areaR =
            ratio

        if emaCenter == nil {
            emaCenter = center
        }

        if emaAreaRatio == nil {
            emaAreaRatio = areaR
        }

        emaCenter =
            emaPoint(
                old: emaCenter!,
                new: center,
                alpha: emaAlpha
            )

        emaAreaRatio =
            emaValue(
                old: emaAreaRatio!,
                new: areaR,
                alpha: emaAlpha
            )

        let centerShift =
            distance(center, emaCenter!)

        let areaDelta =
            abs(areaR - emaAreaRatio!)
            /
            max(emaAreaRatio!, 0.0001)

        let dynamicCenterThr =
            baseCenterShiftThreshold

        let isStableFrame =
            centerShift <= dynamicCenterThr
            &&
            areaDelta <= areaDeltaThreshold

        if isStableFrame {

            stableScore =
                min(requiredStableFrames, stableScore + 1)

        } else {

            stableScore =
                max(0, stableScore - penaltyOnUnstable)
        }

        let isStableNow =
            stableScore >= requiredStableFrames

        log(
            "stableFrame=\(isStableFrame) | score=\(fmt(stableScore))"
        )

        return AutoShootState(
            isStable: isStableNow
        )
    }

    func notifyDidCapture() {
        softReset(keepCooldown: true)
    }

    func resetOnModeChange(keepCooldown: Bool = true) {
        softReset(keepCooldown: keepCooldown)
    }

    // MARK: - Internals

    private func softReset(keepCooldown: Bool = true) {
        stableScore = 0
        isAreaQualified = false
        emaCenter = nil
        emaAreaRatio = nil

        if !keepCooldown {
            lastAutoShotAt = 0
        }
    }

    private func applyPenalty(_ value: CGFloat) {
        stableScore = max(0, stableScore - value)
    }

    private func quadBoundingBoxArea(_ q: Quadrilateral) -> CGFloat {
        let xs = [q.topLeft.x, q.topRight.x, q.bottomRight.x, q.bottomLeft.x]
        let ys = [q.topLeft.y, q.topRight.y, q.bottomRight.y, q.bottomLeft.y]
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return 0 }
        return max(0, (maxX - minX)) * max(0, (maxY - minY))
    }

    private func quadCenter(_ q: Quadrilateral) -> CGPoint {
        let x = (q.topLeft.x + q.topRight.x + q.bottomRight.x + q.bottomLeft.x) / 4
        let y = (q.topLeft.y + q.topRight.y + q.bottomRight.y + q.bottomLeft.y) / 4
        return CGPoint(x: x, y: y)
    }

    private func emaValue(old: CGFloat, new: CGFloat, alpha: CGFloat) -> CGFloat {
        old + alpha * (new - old)
    }

    private func emaPoint(old: CGPoint, new: CGPoint, alpha: CGFloat) -> CGPoint {
        CGPoint(
            x: emaValue(old: old.x, new: new.x, alpha: alpha),
            y: emaValue(old: old.y, new: new.y, alpha: alpha)
        )
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func log(_ msg: String) {
        guard isLoggingEnabled else { return }
    }

    private func fmt(_ v: CGFloat) -> String {
        String(format: "%.4f", Double(v))
    }
}
