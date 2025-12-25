import UIKit

extension UIViewController {

    static func topMost(from base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController

        if let nav = base as? UINavigationController {
            return topMost(from: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topMost(from: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topMost(from: presented)
        }
        return base
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first(where: { $0.isKeyWindow }) }
}
