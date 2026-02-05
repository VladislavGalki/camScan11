import Foundation

struct AnyRoute: Hashable, Identifiable {

    let base: any Route

    var id: AnyHashable {
        AnyHashable(base)
    }

    static func == (lhs: AnyRoute, rhs: AnyRoute) -> Bool {
        AnyHashable(lhs.base) == AnyHashable(rhs.base)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(AnyHashable(base))
    }
}
