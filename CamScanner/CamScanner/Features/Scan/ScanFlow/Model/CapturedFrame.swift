import UIKit

struct CapturedFrame: Equatable {
    var preview: UIImage? = nil
    var original: UIImage? = nil
    var quad: Quadrilateral? = nil
    var drawingData: Data? = nil
    var drawingBase: UIImage? = nil
    var isReady: Bool { preview != nil && original != nil }
}
