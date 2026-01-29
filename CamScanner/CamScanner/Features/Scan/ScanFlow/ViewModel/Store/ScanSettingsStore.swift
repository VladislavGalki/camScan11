import Foundation
import SwiftUI
import Combine

final class ScanSettingsStore: ObservableObject {
    @Published var grid: Bool {
        didSet {
            persistIfNeeded(oldValue: oldValue, newValue: grid, key: ScanSettingsKeys.grid)
        }
    }

    @Published var autoMode: Bool {
        didSet {
            persistIfNeeded(oldValue: oldValue, newValue: autoMode, key: ScanSettingsKeys.autoMode)
        }
    }

    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    
    public var isLivePreviewEnabled: Bool { autoMode }
    
    private var isApplyingExternalChange = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        userDefaults.register(defaults: [
            ScanSettingsKeys.grid: false,
            ScanSettingsKeys.autoMode: true
        ])

        self.grid = userDefaults.bool(forKey: ScanSettingsKeys.grid)
        self.autoMode = userDefaults.bool(forKey: ScanSettingsKeys.autoMode)

        NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: userDefaults
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.applyFromUserDefaults()
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

        let newGrid = userDefaults.bool(forKey: ScanSettingsKeys.grid)
        if grid != newGrid { grid = newGrid }

        let newAutoMode = userDefaults.bool(forKey: ScanSettingsKeys.autoMode)
        if autoMode != newAutoMode { autoMode = newAutoMode }
    }
}
