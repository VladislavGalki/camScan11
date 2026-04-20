import SwiftUI

struct ScanFlowContainerView: View {
    @StateObject private var router = Router()
    @EnvironmentObject private var rootRouter: Router
    @Environment(\.dependencies) private var dependencies

    private let inputModel: ScanInputModel
    private let onDismiss: (() -> Void)?

    init(inputModel: ScanInputModel = ScanInputModel(), onDismiss: (() -> Void)? = nil) {
        self.inputModel = inputModel
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ScanView(
                inputModel: inputModel,
                oncloseClick: {
                    onDismiss?()
                    rootRouter.dismissPresented()
                    Task {
                        try await Task.sleep(for: .seconds(0.25))
                        router.path = NavigationPath()
                    }
                },
                dependencies: dependencies
            )
            .navigationDestination(for: AnyRoute.self) { route in
                ScanFlowResolver.resolve(route.base, dependencies: dependencies)
            }
        }
        .sheet(item: $router.sheetRoute) { route in
            ScanFlowResolver.resolve(route.base, dependencies: dependencies)
        }
        .fullScreenCover(item: $router.presentedRoute) { route in
            ScanFlowResolver.resolve(route.base, dependencies: dependencies)
        }
        .environmentObject(router)
    }
}
