import SwiftUI

@MainActor
final class Router: ObservableObject {

    @Published var path = NavigationPath()

    @Published var presentedRoute: AnyRoute?
    @Published var sheetRoute: AnyRoute?

    // MARK: Push

    func push(_ route: any Route) {
        path.append(AnyRoute(base: route))
    }

    func pop() {
        guard !path.isEmpty else { return }
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
        presentedRoute = nil
    }

    // MARK: Sheet

    func presentSheet(_ route: any Route) {
        sheetRoute = AnyRoute(base: route)
    }

    func dismissSheet() {
        sheetRoute = nil
    }
}
