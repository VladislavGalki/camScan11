import SwiftUI

@main
struct CamScannerApp: App {
    @StateObject private var router = Router()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(router)
        }
    }
}
