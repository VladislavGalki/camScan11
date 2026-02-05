import Foundation

protocol Route: Hashable, Identifiable {}

extension Route {
    var id: Self { self }
}
