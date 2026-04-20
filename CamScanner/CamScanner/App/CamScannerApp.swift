import SwiftUI

@main
struct CamScannerApp: App {
    @StateObject private var router = Router()
    private let dependencies = AppDependencies(persistence: PersistenceController())

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(router)
                .environment(\.dependencies, dependencies)
        }
    }
}
