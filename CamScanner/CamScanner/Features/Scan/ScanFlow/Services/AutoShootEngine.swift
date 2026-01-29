import UIKit
import CoreGraphics

/// Решает: нужно ли прямо сейчас делать автошот.
/// Использует:
/// - гистерезис по площади (enter/keep)
/// - EMA (сглаживание центра и площади)
/// - penalty вместо жесткого reset
final class AutoShootEngine {

    // MARK: - Tuning (можно подправлять)

    /// "Входим" в qualified, когда документ занимает >= enter
    var minAreaEnter: CGFloat = 0.055
    /// "Держим" qualified пока документ >= keep (чтобы не дергалось)
    var minAreaKeep: CGFloat  = 0.045

    /// "Сколько стабильных кадров нужно" (по сути “счетчик стабильности”)
    var requiredStableFrames: CGFloat = 5

    /// Порог по смещению центра (px в координатах детектора)
    var baseCenterShiftThreshold: CGFloat = 10

    /// Порог по относительному изменению площади (0..1)
    var areaDeltaThreshold: CGFloat = 0.12

    /// EMA alpha (0..1). Больше = быстрее реагирует, меньше = сильнее сглаживает
    var emaAlpha: CGFloat = 0.35

    /// Штрафы
    var penaltyOnUnstable: CGFloat = 1.0
    var penaltyOnMissing: CGFloat = 1.5
    var penaltyOnNotQualified: CGFloat = 1.2

    /// Кулдаун между автоснимками
    var minShotInterval: CFTimeInterval = 1.2

    /// Логи
    var isLoggingEnabled: Bool = true

    // MARK: - State

    private var isAreaQualified = false
    private var stableScore: CGFloat = 0
    private var lastAutoShotAt: CFTimeInterval = 0

    private var emaCenter: CGPoint?
    private var emaAreaRatio: CGFloat?

    // MARK: - Public API

    /// Возвращает true, если нужно сделать снимок (вызвать shutter).
    func update(
        enabled: Bool,
        canShoot: Bool,
        quad: Quadrilateral?,
        imageSize: CGSize
    ) -> Bool {

        guard enabled else {
            softReset()
            return false
        }

        guard canShoot else {
            softReset()
            return false
        }

        // quad обязателен для автошота
        guard var quad,
              imageSize.width > 0,
              imageSize.height > 0 else {

            applyPenalty(penaltyOnMissing)
            log("missing quad -> penalty, score=\(fmt(stableScore))/\(fmt(requiredStableFrames))")
            return false
        }

        quad.reorganize()

        // --- Area gate (hysteresis) ---
        let frameArea = max(imageSize.width * imageSize.height, 1)
        let ratio = quadBoundingBoxArea(quad) / frameArea

        if !isAreaQualified {
            isAreaQualified = (ratio >= minAreaEnter)
        } else {
            // держим qualified пока ratio >= keep
            if ratio < minAreaKeep { isAreaQualified = false }
        }

        log("area ratio = \(fmt(ratio)) | enter=\(fmt(minAreaEnter)) keep=\(fmt(minAreaKeep)) | qualified=\(isAreaQualified)")

        guard isAreaQualified else {
            applyPenalty(penaltyOnNotQualified)
            return false
        }

        // --- EMA update ---
        let center = quadCenter(quad)
        let areaR = ratio

        if emaCenter == nil { emaCenter = center }
        if emaAreaRatio == nil { emaAreaRatio = areaR }

        emaCenter = emaPoint(old: emaCenter!, new: center, alpha: emaAlpha)
        emaAreaRatio = emaValue(old: emaAreaRatio!, new: areaR, alpha: emaAlpha)

        let centerShift = distance(center, emaCenter!)
        let areaDelta = abs(areaR - emaAreaRatio!) / max(emaAreaRatio!, 0.0001)

        // можно сделать threshold чуть “плавающим” от величины документа:
        // чем больше документ, тем строже к смещению.
        let dynamicCenterThr = baseCenterShiftThreshold

        let isStable = (centerShift <= dynamicCenterThr) && (areaDelta <= areaDeltaThreshold)

        if isStable {
            stableScore = min(requiredStableFrames, stableScore + 1)
        } else {
            stableScore = max(0, stableScore - penaltyOnUnstable)
        }

        log("stable = \(isStable) | score=\(fmt(stableScore))/\(fmt(requiredStableFrames)) | centerShift=\(fmt(centerShift)) thr=\(fmt(dynamicCenterThr)) | areaΔ=\(fmt(areaDelta))")

        // --- Cooldown + Shot ---
        let now = CACurrentMediaTime()
        guard stableScore >= requiredStableFrames else { return false }
        guard (now - lastAutoShotAt) >= minShotInterval else {
            log("cooldown active: \(fmt(CGFloat(now - lastAutoShotAt)))s / \(fmt(CGFloat(minShotInterval)))s")
            return false
        }

        lastAutoShotAt = now
        stableScore = 0
        log("🔥 AUTO SHOT")
        return true
    }

    /// Вызывай после успешного capture (чтобы не копил старую инерцию)
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
        // EMA не сбрасываем полностью — это и есть “penalty вместо reset”
        // но если score в ноль ушел, можно слегка отпускать EMA:
        if stableScore == 0 {
            // оставляем EMA как есть — обычно так лучше “прощает” дыхание рамки
        }
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
        print("📸 AutoShoot | \(msg)")
    }

    private func fmt(_ v: CGFloat) -> String {
        String(format: "%.4f", Double(v))
    }
}
