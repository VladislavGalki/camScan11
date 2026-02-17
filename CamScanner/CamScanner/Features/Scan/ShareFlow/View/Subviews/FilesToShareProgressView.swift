import SwiftUI

struct FilesToShareProgressView: View {
    let remaining: Int
    private let total: Int = 5
    
    private var progressColor: Color {
        switch remaining {
        case 4...:
            return Color.bg(.success)
        case 3:
            return Color.bg(.warning)
        case 1...2:
            return Color.bg(.destructive)
        default:
            return .clear
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Files to share: \(remaining) of \(total) left")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.secondary))
                .padding(.bottom, 8)
            
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { index in
                    let isActive = index < remaining
                    
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .foregroundStyle(isActive ? progressColor: Color.bg(.controlOnMain)
                        )
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
