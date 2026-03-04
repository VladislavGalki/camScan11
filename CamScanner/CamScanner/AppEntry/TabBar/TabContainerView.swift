import SwiftUI

struct TabContainerView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(AppTab.home)

            FilesView()
                .tag(AppTab.files)

            ToolsPlaceholderView()
                .tag(AppTab.tools)

            ProfilePlaceholderView()
                .tag(AppTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
    }
}
