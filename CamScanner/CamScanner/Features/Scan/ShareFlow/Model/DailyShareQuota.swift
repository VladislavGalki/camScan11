import Foundation

struct DailyShareQuota: Codable {
    let firstShareDate: Date
    var remainingShares: Int
}
