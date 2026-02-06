import UIKit

struct CapturedFrame: Equatable, Hashable {
    var preview: UIImage? = nil
    var original: UIImage? = nil
    var quad: Quadrilateral? = nil
    var drawingData: Data? = nil
    var drawingBase: UIImage? = nil
    var filterType: String? = nil
    var isReady: Bool {
        preview != nil && original != nil
    }
}
