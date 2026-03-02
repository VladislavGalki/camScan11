import SwiftUI

struct TabContainerView: View {

    @Binding var selectedTab: AppTab

    var body: some View {
        switch selectedTab {
        case .home: HomeView()
        case .files: FilesView()
        case .tools: ToolsPlaceholderView()
        case .settings: ProfilePlaceholderView()
        }
    }
}
