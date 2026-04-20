import SwiftUI

enum ScanFlowResolver {
    static func resolve(_ route: any Route, dependencies: AppDependencies) -> AnyView {
        switch route {
        case let r as ScanRoute:
            switch r {
            case let .scanPreview(inputModel, onFinish, onSuccess):
                return AnyView(ScanPreviewView(
                    inputModel: inputModel,
                    onFinish: onFinish,
                    onSuccessFlow: onSuccess,
                    dependencies: dependencies
                ))
            case let.scanCropper(inputModel, onFinish):
                return AnyView(ScanCropperView(
                    input: inputModel,
                    onFinish: onFinish,
                    dependencies: dependencies
                ))
            case let .share(inputModel):
                return AnyView(
                    ShareView(inputModel: inputModel, dependencies: dependencies)
                        .presentationCornerRadius(38)
                )
        }
        default:
            return AnyView(EmptyView())
        }
    }
}
