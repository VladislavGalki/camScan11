import Foundation

final class ShareQuotaService {
    static let shared = ShareQuotaService()
    private init() {}
    
    private let key = "daily_share_quota"
    private let maxSharesPerDay = 5
    
    func remainingShares() -> Int {
        do {
            return try KeychainService.shared
                .load(DailyShareQuota.self, for: key)?
                .remainingShares ?? maxSharesPerDay
        } catch {
            return maxSharesPerDay
        }
    }
    
    func consumeShare() throws {
            guard var quota = try KeychainService.shared.load(DailyShareQuota.self, for: key) else { return }
            guard quota.remainingShares > 0 else { return }

            quota.remainingShares -= 1
            try KeychainService.shared.save(quota, for: key)
    }
    
    func refreshQuotaIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())

        do {
            if var quota = try KeychainService.shared.load(DailyShareQuota.self, for: key) {
                let storedDay = Calendar.current.startOfDay(for: quota.firstShareDate)
                if storedDay != today {
                    quota = DailyShareQuota(
                        firstShareDate: today,
                        remainingShares: maxSharesPerDay
                    )

                    try KeychainService.shared.save(quota, for: key)
                }
            } else {
                let quota = DailyShareQuota(
                    firstShareDate: today,
                    remainingShares: maxSharesPerDay
                )

                try KeychainService.shared.save(quota, for: key)
            }
        } catch {
        }
    }
}
