import SwiftUI

struct AppEntryView: View {

    @State private var selectedTab: AppTab = .home
    @State private var cameraButtonFrame: CGRect = .zero
    
    @StateObject private var tabBar = TabBarController()

    var body: some View {
        TabContainerView(selectedTab: $selectedTab)
            .environmentObject(tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if tabBar.isTabBarVisible {
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        cameraButtonFrame: $cameraButtonFrame,
                        onScanTap: presentScan
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeOut(duration: 0.25), value: tabBar.isTabBarVisible)
    }

    private func presentScan() {
        guard let presenter = UIViewController.topMost() else { return }
        ScanModal.present(from: presenter, sourceFrameGlobal: cameraButtonFrame)
    }
}
