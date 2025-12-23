import SwiftUI

struct TabContainerView: View {

    @Binding var selectedTab: AppTab

    var body: some View {
        switch selectedTab {
        case .home: HomePlaceholderView()
        case .files: FilesPlaceholderView()
        case .tools: ToolsPlaceholderView()
        case .profile: ProfilePlaceholderView()
        }
    }
}
