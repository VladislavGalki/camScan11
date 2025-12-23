import SwiftUI

struct CustomTabBar: View {

    @Binding var selectedTab: AppTab
    @Binding var cameraButtonFrame: CGRect

    let onScanTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(.systemBackground))
                .shadow(radius: 8)
                .frame(height: 60)
                .padding(.horizontal, 16)

            HStack {
                tabButton(.home)
                tabButton(.files)

                Spacer(minLength: 0)

                tabButton(.tools)
                tabButton(.profile)
            }
            .padding(.horizontal, 24)
            .frame(height: 60)

            scanButton
                .offset(y: -28)
        }
        .padding(.bottom, 10)
        .onPreferenceChange(FramePreferenceKey.self) { frame in
            cameraButtonFrame = frame
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                Text(tab.title)
                    .font(.caption2)
            }
            .foregroundStyle(selectedTab == tab ? .green : .secondary)
            .frame(maxWidth: .infinity)
        }
    }

    private var scanButton: some View {
        Button(action: onScanTap) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 64, height: 64)

                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .reportFrame()
    }
}
