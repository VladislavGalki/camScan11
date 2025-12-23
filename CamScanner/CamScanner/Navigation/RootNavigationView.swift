import SwiftUI

struct RootNavigationView<Root: View>: View {

    @StateObject private var router = Router()

    let root: Root
    let destinationBuilder: (any Route) -> AnyView

    var body: some View {
        NavigationStack(path: $router.path) {
            root
                .navigationDestination(for: AnyRoute.self) { route in
                    destinationBuilder(route.base)
                }
        }
        .environmentObject(router)
    }
}
