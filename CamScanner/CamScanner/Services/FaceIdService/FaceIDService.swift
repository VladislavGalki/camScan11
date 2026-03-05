import LocalAuthentication

final class FaceIDService {
    static let shared = FaceIDService()
    
    private init() {}

    func requestAuthorizationIfNeeded() async -> Bool {
        if UserDefaults.standard.bool(forKey: "faceIdEnabled") {
            return true
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            return false
        }

        let success = await evaluate(context: context, reason: reasonText(context))

        if success {
            UserDefaults.standard.set(true, forKey: "faceIdEnabled")
        }

        return success
    }

    func authenticateForUnlock() async -> Bool {
        let context = LAContext()

        guard isBiometryAvailable() else {
            return false
        }

        return await evaluate(context: context, reason: reasonText(context))
    }
    
    private func isBiometryAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?

        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }

    private func evaluate(context: LAContext, reason: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, _ in

                DispatchQueue.main.async {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    private func reasonText(_ context: LAContext) -> String {
        switch context.biometryType {
        case .faceID:
            return "Unlock document with Face ID"
        case .touchID:
            return "Unlock document with Touch ID"
        default:
            return "Authenticate to open document"
        }
    }
}
