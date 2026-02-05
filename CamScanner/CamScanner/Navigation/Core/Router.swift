import SwiftUI

@MainActor
final class Router: ObservableObject {

    @Published var path = NavigationPath()
    @Published var presentedRoute: AnyRoute?

    func push(_ route: any Route) {
        path.append(AnyRoute(base: route))
    }

    func present(_ route: any Route) {
        presentedRoute = AnyRoute(base: route)
    }

    func dismissPresented() {
        presentedRoute = nil
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
