import Foundation

struct AnyRoute: Hashable {

    let base: any Route

    static func == (lhs: AnyRoute, rhs: AnyRoute) -> Bool {
        lhs.base.hashValue == rhs.base.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(base.hashValue)
    }
}
