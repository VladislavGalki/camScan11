import CoreImage
import Foundation

public enum ImageScannerControllerError: Error {
    case authorization
    case inputDevice
    case capture
    case ciImageCreation
}

extension ImageScannerControllerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authorization:
            return "Failed to get the user's authorization for camera."
        case .inputDevice:
            return "Could not setup input device."
        case .capture:
            return "Could not capture picture."
        case .ciImageCreation:
            return "Internal Error - Could not create CIImage"
        }
    }

}
