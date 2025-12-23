import SwiftUI

struct AppEntryView: View {

    @State private var selectedTab: AppTab = .home
    @State private var cameraButtonFrame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .bottom) {

            TabContainerView(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(
                selectedTab: $selectedTab,
                cameraButtonFrame: $cameraButtonFrame,
                onScanTap: presentScan
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func presentScan() {
        guard let presenter = UIViewController.topMost() else { return }
        ScanModal.present(from: presenter, sourceFrameGlobal: cameraButtonFrame)
    }
}
