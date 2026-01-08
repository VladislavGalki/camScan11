import SwiftUI

struct AppRootView: View {
    let persistence = PersistenceController.shared

    var body: some View {
        RootNavigationView(
            root: AppEntryView(),
            destinationBuilder: resolve
        )
        .environment(\.managedObjectContext,
                      persistence.container.viewContext)
    }

    private func resolve(_ route: any Route) -> AnyView {
        AnyView(EmptyView())
    }
}
