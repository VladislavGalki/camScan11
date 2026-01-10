import SwiftUI

struct AppRootView: View {
    var body: some View {
        RootNavigationView(
            root: AppEntryView(),
            destinationBuilder: resolve
        )
    }

    private func resolve(_ route: any Route) -> AnyView {
        switch route {

        case let r as HomeRoute:
            switch r {
            case .openDocument(let id):
                return AnyView(DocumentPreviewEntryView(documentID: id))
            }

        default:
            return AnyView(EmptyView())
        }
    }
}
