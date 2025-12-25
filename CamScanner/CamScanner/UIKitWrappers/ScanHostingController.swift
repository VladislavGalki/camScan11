import SwiftUI
import UIKit

final class ScanHostingController: UIHostingController<ScanView> {

    var transitioningDelegateStrongRef: UIViewControllerTransitioningDelegate?

    init(onClose: @escaping () -> Void) {
        super.init(rootView: ScanView(onClose: onClose))
    }

    @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
