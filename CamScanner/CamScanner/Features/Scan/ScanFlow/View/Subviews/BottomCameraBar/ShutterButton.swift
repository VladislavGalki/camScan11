import SwiftUI

struct CaptureShutterButton: View {
    let shoudStartTimer: Bool
    let buttonDisabled: Bool
    let action: () -> Void
    
    private let size: CGFloat = 80
    
    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(.bg(.controlImmersive))
                .appBorderModifier(.border(.primaryImmersive), width: 1, radius: 100, corners: .allCorners)
            
            Circle()
                .foregroundStyle(.bg(.surface).opacity(buttonDisabled ? 0.3 : 1))
                .padding(8)
        }
        .frame(width: size, height: size)
        .onTapGesture {
            guard !buttonDisabled else { return }
            action()
        }
    }
}
