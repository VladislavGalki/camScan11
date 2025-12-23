import SwiftUI

struct NavigationPlaceholder: View {

    let title: String

    var body: some View {
        VStack {
            Spacer()
            Text(title)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
