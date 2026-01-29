import Foundation
import Combine

@MainActor
final class ScanStore: ObservableObject {

    let settings: ScanSettingsStore
    let ui: ScanUIStateStore

    private var cancellables = Set<AnyCancellable>()

    init(
        settings: ScanSettingsStore = ScanSettingsStore(),
        ui: ScanUIStateStore = ScanUIStateStore()
    ) {
        self.settings = settings
        self.ui = ui

        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        ui.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
