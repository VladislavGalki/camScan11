import UIKit

enum SignatureProcessingService {

    static func processAndSave(croppedImage: UIImage) async -> UUID? {
        let processed: UIImage? = await Task.detached(priority: .userInitiated) {
            let renderer = OpenCVFilterRenderer()
            return renderer.extractSignatureWithTransparentBackground(
                image: croppedImage.normalizedUp()
            )
        }.value

        guard let processed else {
            postToast("Unable to process signature")
            return nil
        }

        do {
            let id = try DocumentRepository.shared.saveSignature(
                image: processed,
                strokeData: nil,
                colorHex: "#020202FF",
                brushSize: 10
            )
            postToast("Signature ready")
            return id
        } catch {
            postToast("Unable to save signature")
            return nil
        }
    }

    private static func postToast(_ title: String) {
        NotificationCenter.default.post(
            name: .appGlobalToastRequested,
            object: nil,
            userInfo: ["title": title]
        )
    }
}
