import SwiftUI

struct RootNavigationView<Root: View>: View {
    let root: Root
    let destinationBuilder: (any Route) -> AnyView
    
    @EnvironmentObject private var router: Router

    var body: some View {
        NavigationStack(path: $router.path) {
            root
                .navigationDestination(for: AnyRoute.self) { route in
                    destinationBuilder(route.base)
                }
        }
        .fullScreenCover(item: $router.presentedRoute) { route in
            destinationBuilder(route.base)
        }
        .sheet(item: $router.sheetRoute) { route in
            destinationBuilder(route.base)
        }
        .environmentObject(router)
    }
}
