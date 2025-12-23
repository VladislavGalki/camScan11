import SwiftUI

@MainActor
final class Router: ObservableObject {

    @Published var path = NavigationPath()

    func push(_ route: any Route) {
        path.append(AnyRoute(base: route))
    }

    func pop() {
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
