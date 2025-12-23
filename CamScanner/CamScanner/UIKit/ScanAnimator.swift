import UIKit

final class ScanAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    private let isPresenting: Bool
    private let sourceFrame: CGRect
    private let duration: TimeInterval = 0.35

    init(isPresenting: Bool, sourceFrame: CGRect) {
        self.isPresenting = isPresenting
        self.sourceFrame = sourceFrame
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        let container = ctx.containerView

        if isPresenting {
            guard let toVC = ctx.viewController(forKey: .to) else {
                ctx.completeTransition(false); return
            }

            let toView = toVC.view!
            toView.frame = ctx.finalFrame(for: toVC)
            toView.alpha = 1
            toView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            toView.isHidden = true

            let morphView = UIView(frame: sourceFrame)
            morphView.backgroundColor = .black
            morphView.layer.cornerRadius = sourceFrame.height / 2
            morphView.layer.masksToBounds = true

            let startCorner = min(sourceFrame.width, sourceFrame.height) / 2
            morphView.layer.cornerRadius = startCorner

            container.addSubview(toView)
            container.addSubview(morphView)

            let finalRect = container.bounds
            let endCorner: CGFloat = 16

            // 1) Анимируем фрейм (пружина)
            UIView.animate(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0.0,
                options: [.curveEaseInOut]
            ) {
                morphView.frame = finalRect
                toView.alpha = 1
                toView.transform = .identity
            } completion: { finished in
                toView.isHidden = false
                morphView.removeFromSuperview()
                ctx.completeTransition(finished)
            }

            let cornerAnim = CABasicAnimation(keyPath: "cornerRadius")
            cornerAnim.fromValue = startCorner
            cornerAnim.toValue = endCorner
            cornerAnim.duration = duration * 0.85
            cornerAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cornerAnim.fillMode = .forwards
            cornerAnim.isRemovedOnCompletion = false
            morphView.layer.add(cornerAnim, forKey: "cornerRadius")

            DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.85) {
                morphView.layer.cornerRadius = 0
                morphView.layer.removeAnimation(forKey: "cornerRadius")
            }
        } else {
            guard let fromVC = ctx.viewController(forKey: .from) else {
                ctx.completeTransition(false); return
            }

            let fromView = fromVC.view!

            let morphView = UIView(frame: container.bounds)
            morphView.backgroundColor = .black
            morphView.layer.cornerRadius = 0
            morphView.layer.masksToBounds = true

            container.insertSubview(morphView, belowSubview: fromView)

            UIView.animate(
                withDuration: duration * 0.9,
                delay: 0,
                usingSpringWithDamping: 0.92,
                initialSpringVelocity: 0.0,
                options: [.curveEaseInOut]
            ) {
                fromView.alpha = 0
                morphView.frame = self.sourceFrame
                morphView.layer.cornerRadius = self.sourceFrame.height / 2
            } completion: { finished in
                fromView.removeFromSuperview()
                morphView.removeFromSuperview()
                ctx.completeTransition(finished)
            }
        }
    }
}
