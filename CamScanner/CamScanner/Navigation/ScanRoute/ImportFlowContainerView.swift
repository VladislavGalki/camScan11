import SwiftUI

struct ImportFlowContainerView: View {
    @StateObject private var router = Router()
    @StateObject private var flowState = ImportFlowState()
    @EnvironmentObject private var rootRouter: Router
    @Environment(\.dependencies) private var dependencies

    let inputModel: ScanCropperInputModel

    var body: some View {
        NavigationStack(path: $router.path) {
            ScanCropperView(
                input: inputModel,
                onFinish: { previewInputModel in
                    flowState.cropperResult = previewInputModel
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
        .onAppear {
            router.onPopEmptyHandler = { [weak flowState, weak router, weak rootRouter] in
                guard let flowState, let router, let rootRouter else { return }
                if let result = flowState.cropperResult {
                    flowState.cropperResult = nil
                    router.push(
                        ScanRoute.scanPreview(
                            result,
                            onFinish: { _ in },
                            onSuccessFlow: {
                                rootRouter.dismissPresented()
                                Task {
                                    try? await Task.sleep(for: .seconds(0.25))
                                    router.path = NavigationPath()
                                }
                            }
                        )
                    )
                } else {
                    rootRouter.dismissPresented()
                }
            }
        }
    }
}

@MainActor
private class ImportFlowState: ObservableObject {
    var cropperResult: ScanPreviewInputModel?
}
