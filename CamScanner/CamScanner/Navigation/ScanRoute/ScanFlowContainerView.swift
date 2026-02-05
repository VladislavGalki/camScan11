import SwiftUI

struct ScanFlowContainerView: View {
    
    @StateObject private var router = Router()
    @EnvironmentObject private var rootRouter: Router
    
    var body: some View {
        NavigationStack(path: $router.path) {
            ScanView(oncloseClick: {
                rootRouter.dismissPresented()
            })
            .navigationDestination(for: AnyRoute.self) { route in
                ScanFlowResolver.resolve(route.base)
            }
        }
        .environmentObject(router)
    }
}
