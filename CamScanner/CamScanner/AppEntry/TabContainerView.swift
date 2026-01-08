import SwiftUI

struct TabContainerView: View {

    @Binding var selectedTab: AppTab

    var body: some View {
        switch selectedTab {
        case .home: HomeView()
        case .files: FilesPlaceholderView()
        case .tools: ToolsPlaceholderView()
        case .profile: ProfilePlaceholderView()
        }
    }
}
