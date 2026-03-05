import CoreMotion
import Foundation
import UIKit

extension CaptureSession {
    func setImageOrientation() {
        let motion = CMMotionManager()

        motion.accelerometerUpdateInterval = 0.01

        guard motion.isAccelerometerAvailable else { return }

        motion.startAccelerometerUpdates(to: OperationQueue()) { data, error in
            guard let data, error == nil else { return }

            let motionThreshold = 0.35

            if data.acceleration.x >= motionThreshold {
                self.editImageOrientation = .left
            } else if data.acceleration.x <= -motionThreshold {
                self.editImageOrientation = .right
            } else {
                self.editImageOrientation = .up
            }

            motion.stopAccelerometerUpdates()

            switch UIDevice.current.orientation {
            case .landscapeLeft:
                self.editImageOrientation = .right
            case .landscapeRight:
                self.editImageOrientation = .left
            default:
                break
            }
        }
    }
}
