import SwiftUI

enum ScanFlowResolver {
    static func resolve(_ route: any Route) -> AnyView {
        switch route {
        case let r as ScanRoute:
            switch r {
            case let .scanPreview(inputModel, onFinish):
                return AnyView(ScanPreviewView(inputModel: inputModel, onFinish: onFinish))
            case let.scanCropper(inputModel, onFinish):
                return AnyView(ScanCropperView(input: inputModel, onFinish: onFinish))
        }
        default:
            return AnyView(EmptyView())
        }
    }
}
