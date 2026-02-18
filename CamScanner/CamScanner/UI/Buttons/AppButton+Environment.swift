import SwiftUI

private struct AppButtonEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var appButtonEnabled: Bool {
        get { self[AppButtonEnabledKey.self] }
        set { self[AppButtonEnabledKey.self] = newValue }
    }
}

extension View {
    func appButtonEnabled(_ isEnabled: Bool) -> some View {
        environment(\.appButtonEnabled, isEnabled)
    }
}

private struct AppButtonLoaderKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var appButtonIsLoading: Bool {
        get { self[AppButtonLoaderKey.self] }
        set { self[AppButtonLoaderKey.self] = newValue }
    }
}

extension View {
    func appButtonIsLoading(_ isLoading: Bool) -> some View {
        environment(\.appButtonIsLoading, isLoading)
    }
}
