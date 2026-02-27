import Foundation

struct FilterState: Equatable, Hashable, Codable {
    var type: DocumentFilterType = .original
    var adjustment: CGFloat = 0.0
    var rotationAngle: CGFloat = 0
}
