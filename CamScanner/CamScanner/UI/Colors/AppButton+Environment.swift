import SwiftUI

private struct AppButtonEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    /// Управляет enabled/disabled состоянием AppButton (не влияет на системные control-ы).
    var appButtonEnabled: Bool {
        get { self[AppButtonEnabledKey.self] }
        set { self[AppButtonEnabledKey.self] = newValue }
    }
}

extension View {
    /// Выключает/включает AppButton через environment (не использует .disabled()).
    func appButtonEnabled(_ isEnabled: Bool) -> some View {
        environment(\.appButtonEnabled, isEnabled)
    }
}
