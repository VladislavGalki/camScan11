import Foundation
import SwiftUI
import Combine

/// Вынос @AppStorage из ViewModel.
/// Здесь же можно централизованно менять дефолты/ключи.
final class ScanSettingsStore: ObservableObject {

    // MARK: - Stored keys

    @Published var grid: Bool {
        didSet { UserDefaults.standard.set(grid, forKey: ScanSettingsKeys.grid) }
    }

    @Published var autoShoot: Bool {
        didSet { UserDefaults.standard.set(autoShoot, forKey: ScanSettingsKeys.autoShoot) }
    }

    @Published var autoCrop: Bool {
        didSet { UserDefaults.standard.set(autoCrop, forKey: ScanSettingsKeys.autoCrop) }
    }

    @Published var textOrientationRotate: Bool {
        didSet { UserDefaults.standard.set(textOrientationRotate, forKey: ScanSettingsKeys.textOrientationRotate) }
    }

    @Published var volumeShutter: Bool {
        didSet { UserDefaults.standard.set(volumeShutter, forKey: ScanSettingsKeys.volumeShutter) }
    }

    private var cancellables = Set<AnyCancellable>()

    init(userDefaults: UserDefaults = .standard) {
        self.grid = userDefaults.bool(forKey: ScanSettingsKeys.grid)
        self.autoShoot = userDefaults.bool(forKey: ScanSettingsKeys.autoShoot)

        // для bool-ключей, которых может не быть — поставим адекватные дефолты:
        self.autoCrop = userDefaults.object(forKey: ScanSettingsKeys.autoCrop) as? Bool ?? true
        self.textOrientationRotate = userDefaults.object(forKey: ScanSettingsKeys.textOrientationRotate) as? Bool ?? true
        self.volumeShutter = userDefaults.object(forKey: ScanSettingsKeys.volumeShutter) as? Bool ?? true

        // синхронизация, если настройки меняются где-то еще
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let ud = UserDefaults.standard
                self.grid = ud.bool(forKey: ScanSettingsKeys.grid)
                self.autoShoot = ud.bool(forKey: ScanSettingsKeys.autoShoot)
                self.autoCrop = ud.object(forKey: ScanSettingsKeys.autoCrop) as? Bool ?? true
                self.textOrientationRotate = ud.object(forKey: ScanSettingsKeys.textOrientationRotate) as? Bool ?? true
                self.volumeShutter = ud.object(forKey: ScanSettingsKeys.volumeShutter) as? Bool ?? true
            }
            .store(in: &cancellables)
    }
}
