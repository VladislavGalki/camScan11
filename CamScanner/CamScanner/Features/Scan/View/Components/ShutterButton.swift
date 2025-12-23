import SwiftUI

struct ShutterButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.cyan, lineWidth: 4)
                    .frame(width: 78, height: 78)

                Circle()
                    .fill(Color.white)
                    .frame(width: 62, height: 62)

                if isBusy {
                    ProgressView().tint(.black)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}
