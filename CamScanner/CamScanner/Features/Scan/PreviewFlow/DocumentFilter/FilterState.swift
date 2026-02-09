import Foundation

struct FilterState: Equatable, Hashable, Codable {
    var type: DocumentFilterType = .original
    var brightness: CGFloat = 0
    var rotationAngle: CGFloat = 0
}
