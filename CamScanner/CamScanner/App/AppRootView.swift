import SwiftUI

struct AppRootView: View {
    let persistence = PersistenceController.shared

    var body: some View {
        RootNavigationView(
            root: AppEntryView(),
            destinationBuilder: resolve
        )
    }

    private func resolve(_ route: any Route) -> AnyView {
        AnyView(EmptyView())
    }
}
