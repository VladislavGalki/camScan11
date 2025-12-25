import UIKit

final class ScanTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {

    private let sourceFrame: CGRect

    init(sourceFrame: CGRect) {
        self.sourceFrame = sourceFrame
        super.init()
    }

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ScanAnimator(isPresenting: true, sourceFrame: sourceFrame)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ScanAnimator(isPresenting: false, sourceFrame: sourceFrame)
    }
}
