import SwiftUI

struct ScanTopBar: View {

    let flashIconName: String
    let onClose: () -> Void

    let onFlashTap: () -> Void
    let onQualityTap: () -> Void
    let onFiltersTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button(action: onFlashTap) {
                Image(systemName: flashIconName)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }

            Button(action: onQualityTap) {
                Text("HD")
                    .font(.caption).bold()
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }

            Button(action: onFiltersTap) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }

            Button(action: onSettingsTap) {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(Color.black)
    }
}
