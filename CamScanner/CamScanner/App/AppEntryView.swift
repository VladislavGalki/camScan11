import SwiftUI

struct AppEntryView: View {

    @State private var selectedTab: AppTab = .home
    @State private var cameraButtonFrame: CGRect = .zero

    var body: some View {
        TabContainerView(selectedTab: $selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(
                    selectedTab: $selectedTab,
                    cameraButtonFrame: $cameraButtonFrame,
                    onScanTap: presentScan
                )
            }
    }

    private func presentScan() {
        guard let presenter = UIViewController.topMost() else { return }
        ScanModal.present(from: presenter, sourceFrameGlobal: cameraButtonFrame)
    }
}
