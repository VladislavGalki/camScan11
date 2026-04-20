import Foundation

final class LockedActionExecutor {
    private let faceIdService: FaceIDService

    init(faceIdService: FaceIDService) {
        self.faceIdService = faceIdService
    }

    struct Result {
        let requiresPin: Bool
        let success: Bool
    }

    func execute(isLocked: Bool, isFaceIdEnabled: Bool) async -> Result {
        guard isLocked else {
            return Result(requiresPin: false, success: true)
        }

        if isFaceIdEnabled {
            let authenticated = await faceIdService.authenticateForUnlock()

            if authenticated {
                return Result(requiresPin: false, success: true)
            }
        }

        return Result(requiresPin: true, success: false)
    }
}
