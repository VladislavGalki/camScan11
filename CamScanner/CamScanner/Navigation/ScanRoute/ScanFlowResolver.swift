import SwiftUI

enum ScanFlowResolver {
    static func resolve(_ route: any Route) -> AnyView {
        switch route {
        case let r as ScanRoute:
            switch r {
            case let .scanPreview(inputModel):
                return AnyView(ScanPreviewView(inputModel: inputModel))
        }
        default:
            return AnyView(EmptyView())
        }
    }
}
