import UIKit

enum ScanModal {

    static func present(from presenter: UIViewController, sourceFrameGlobal: CGRect) {
        let scanVC = ScanHostingController {
            presenter.dismiss(animated: true)
        }

        let sourceFrame = convertToWindowCoordinates(presenter: presenter, globalFrame: sourceFrameGlobal)

        let transitioning = ScanTransitioningDelegate(sourceFrame: sourceFrame)
        scanVC.modalPresentationStyle = .custom
        scanVC.transitioningDelegate = transitioning
        scanVC.transitioningDelegateStrongRef = transitioning
        presenter.present(scanVC, animated: true)
    }

    private static func convertToWindowCoordinates(
        presenter: UIViewController,
        globalFrame: CGRect
    ) -> CGRect {

        guard let window = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else {
            return globalFrame
        }

        return globalFrame
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first(where: { $0.isKeyWindow }) }
}
