import SwiftUI

@MainActor
final class TabBarController: ObservableObject {
    @Published var isTabBarVisible: Bool = true
}
