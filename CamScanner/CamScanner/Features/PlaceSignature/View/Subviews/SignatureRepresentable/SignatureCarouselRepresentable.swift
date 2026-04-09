import SwiftUI

struct SignatureCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var signatureItems: [DocumentSignatureItem]
    var selectedSignatureID: UUID?
    var isScrollDisabled: Bool = false
    var isInteractionDisabled: Bool = false
    weak var delegate: SignaturePageDelegate?

    func makeUIViewController(context: Context) -> SignatureCarouselController {
        SignatureCarouselController(
            models: models,
            signatureItems: signatureItems,
            selectedSignatureID: selectedSignatureID,
            isInteractionDisabled: isInteractionDisabled,
            delegate: delegate
        )
    }

    func updateUIViewController(_ vc: SignatureCarouselController, context: Context) {
        vc.update(
            models: models,
            signatureItems: signatureItems,
            selectedSignatureID: selectedSignatureID,
            isInteractionDisabled: isInteractionDisabled,
            isScrollDisabled: isScrollDisabled
        )
    }
}
