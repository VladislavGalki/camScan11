import SwiftUI

@MainActor
final class Router: ObservableObject {

    @Published var path = NavigationPath()

    @Published var presentedRoute: AnyRoute?
    @Published var sheetRoute: AnyRoute?

    var onPopEmptyHandler: (() -> Void)?

    // MARK: Push

    func push(_ route: any Route) {
        path.append(AnyRoute(base: route))
    }

    func pop() {
        guard !path.isEmpty else {
            onPopEmptyHandler?()
            return
        }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    // MARK: Fullscreen

    func present(_ route: any Route) {
        presentedRoute = AnyRoute(base: route)
    }

    func dismissPresented() {
        DispatchQueue.main.async { [weak self] in
            self?.presentedRoute = nil
        }
    }

    // MARK: Sheet

    func presentSheet(_ route: any Route) {
        sheetRoute = AnyRoute(base: route)
    }

    func dismissSheet() {
        DispatchQueue.main.async { [weak self] in
            self?.sheetRoute = nil
        }
    }
}
