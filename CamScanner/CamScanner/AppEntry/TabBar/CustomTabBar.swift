import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @Binding var cameraButtonFrame: CGRect
    
    private let tabScanButtonSize: CGFloat = 78
    
    let onScanTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabBarButton(.home)
            tabBarButton(.files)
            
            Spacer(minLength: tabScanButtonSize)
            
            tabBarButton(.tools)
            tabBarButton(.settings)
        }
        .overlay {
            tabScanButton()
                .onTapGesture {
                    onScanTap()
                }
        }
        .padding(.top, 4)
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .appBorderModifier(.border(.primary), radius: 24, corners: [.topLeft, .topRight])
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabBarButton(_ tab: AppTab) -> some View {
        VStack(spacing: 4) {
            Image(appIcon: tab.icon)
                .renderingMode(.template)
                .foregroundStyle(
                    selectedTab == tab
                    ? Color.elements(.accent)
                    : Color.elements(.navigationDefault)
                )
            
            Text(tab.title)
                .appTextStyle(.tabBar)
                .foregroundStyle(
                    selectedTab == tab
                    ? Color.text(.accent)
                    : Color.text(.secondary)
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .onTapGesture {
            selectedTab = tab
        }
    }
    
    private func tabScanButton() -> some View {
        Circle()
            .foregroundStyle(
                RadialGradient(
                    stops: [
                        .init(color: Color.rgba(121, 192, 255, 1), location: 0.0),
                        .init(color: Color.rgba(0, 136, 255, 1), location: 0.55),
                        .init(color: Color.rgba(0, 108, 203, 1), location: 1.0),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: tabScanButtonSize / 2
                )
            )
            .overlay {
                Image(appIcon: .plus)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
            }
            .appBorderModifier(.border(.primary), width: 3, radius: 100, corners: .allCorners)
            .frame(width: tabScanButtonSize, height: tabScanButtonSize)
    }
}
