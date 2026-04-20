import SwiftUI

struct TabContainerView: View {
    @Binding var selectedTab: AppTab
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(dependencies: dependencies)
                .tag(AppTab.home)

            FilesView(dependencies: dependencies)
                .tag(AppTab.files)

            ToolsPlaceholderView()
                .tag(AppTab.tools)

            ProfilePlaceholderView()
                .tag(AppTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
    }
}
