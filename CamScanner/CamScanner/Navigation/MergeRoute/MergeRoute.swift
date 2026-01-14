import Foundation

enum MergeRoute: Route {
    case selectDocuments
    case arrangeDocuments(ids: [UUID])
}
