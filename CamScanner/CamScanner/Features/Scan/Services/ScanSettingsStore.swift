import Foundation
import SwiftUI
import Combine

/// Вынос @AppStorage из ViewModel.
/// Здесь же можно централизованно менять дефолты/ключи.
final class ScanSettingsStore: ObservableObject {

    // MARK: - Stored keys

    @Published var grid: Bool {
        didSet { persistIfNeeded(oldValue: oldValue, newValue: grid, key: ScanSettingsKeys.grid) }
    }

    @Published var autoShoot: Bool {
        didSet { persistIfNeeded(oldValue: oldValue, newValue: autoShoot, key: ScanSettingsKeys.autoShoot) }
    }

    @Published var autoCrop: Bool {
        didSet { persistIfNeeded(oldValue: oldValue, newValue: autoCrop, key: ScanSettingsKeys.autoCrop) }
    }

    @Published var textOrientationRotate: Bool {
        didSet { persistIfNeeded(oldValue: oldValue, newValue: textOrientationRotate, key: ScanSettingsKeys.textOrientationRotate) }
    }

    @Published var volumeShutter: Bool {
        didSet { persistIfNeeded(oldValue: oldValue, newValue: volumeShutter, key: ScanSettingsKeys.volumeShutter) }
    }

    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    /// Защита от feedback-loop:
    /// когда мы применяем значения, пришедшие из UserDefaults.didChangeNotification,
    /// мы НЕ должны снова писать их обратно в UserDefaults.
    private var isApplyingExternalChange = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        self.grid = userDefaults.bool(forKey: ScanSettingsKeys.grid)
        self.autoShoot = userDefaults.bool(forKey: ScanSettingsKeys.autoShoot)

        // для bool-ключей, которых может не быть — поставим адекватные дефолты:
        self.autoCrop = userDefaults.object(forKey: ScanSettingsKeys.autoCrop) as? Bool ?? true
        self.textOrientationRotate = userDefaults.object(forKey: ScanSettingsKeys.textOrientationRotate) as? Bool ?? true
        self.volumeShutter = userDefaults.object(forKey: ScanSettingsKeys.volumeShutter) as? Bool ?? true

        // синхронизация, если настройки меняются где-то еще
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: userDefaults)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyFromUserDefaults()
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    private func persistIfNeeded(oldValue: Bool, newValue: Bool, key: String) {
        guard oldValue != newValue else { return }
        guard !isApplyingExternalChange else { return }
        userDefaults.set(newValue, forKey: key)
    }

    private func applyFromUserDefaults() {
        isApplyingExternalChange = true
        defer { isApplyingExternalChange = false }

        // Важно: присваиваем только если реально изменилось,
        // чтобы не триггерить лишние обновления SwiftUI.
        let newGrid = userDefaults.bool(forKey: ScanSettingsKeys.grid)
        if grid != newGrid { grid = newGrid }

        let newAutoShoot = userDefaults.bool(forKey: ScanSettingsKeys.autoShoot)
        if autoShoot != newAutoShoot { autoShoot = newAutoShoot }

        let newAutoCrop = userDefaults.object(forKey: ScanSettingsKeys.autoCrop) as? Bool ?? true
        if autoCrop != newAutoCrop { autoCrop = newAutoCrop }

        let newTextRotate = userDefaults.object(forKey: ScanSettingsKeys.textOrientationRotate) as? Bool ?? true
        if textOrientationRotate != newTextRotate { textOrientationRotate = newTextRotate }

        let newVolume = userDefaults.object(forKey: ScanSettingsKeys.volumeShutter) as? Bool ?? true
        if volumeShutter != newVolume { volumeShutter = newVolume }
    }
}
