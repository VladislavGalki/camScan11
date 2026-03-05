import SwiftUI

struct AppEntryView: View {

    @State private var selectedTab: AppTab = .home
    @State private var cameraButtonFrame: CGRect = .zero
    
    @StateObject private var tabBar = TabBarController()
    
    @EnvironmentObject private var router: Router
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        TabContainerView(selectedTab: $selectedTab)
            .environmentObject(tabBar)
            .overlay(alignment: .bottom) {
                if tabBar.isTabBarVisible {
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        cameraButtonFrame: $cameraButtonFrame,
                        onScanTap: {
                            router.present(ScanFlowRoute.scan)
                        }
                    )
                    .transition(.identity.combined(with: .move(edge: .bottom).combined(with: .opacity)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: tabBar.isTabBarVisible)
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
