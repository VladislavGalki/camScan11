import SwiftUI

enum ScanFlowResolver {
    static func resolve(_ route: any Route) -> AnyView {
        switch route {
        case let r as ScanRoute:
            switch r {
            case .scanPreview:
                return AnyView(ScanPreviewView())
        }
        default:
            return AnyView(EmptyView())
        }
    }
}
