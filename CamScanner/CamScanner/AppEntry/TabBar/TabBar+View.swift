import SwiftUI

extension View {
    func tabBarVisible(_ visible: Bool) -> some View {
        modifier(TabBarVisibilityModifier(visible: visible))
    }
}

private struct TabBarVisibilityModifier: ViewModifier {
    @EnvironmentObject var tabBar: TabBarController
    
    let visible: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                tabBar.isTabBarVisible = visible
            }
            .onDisappear {
                tabBar.isTabBarVisible = true
            }
    }
}
