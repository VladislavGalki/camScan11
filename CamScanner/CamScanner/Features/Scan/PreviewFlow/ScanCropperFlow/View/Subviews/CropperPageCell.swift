import UIKit

final class CropperPageCell: UICollectionViewCell {

    static let reuseId = "CropperPageCell"

    private weak var parentVC: UIViewController?
    private var cropController: DocumentCropperViewController?
    
    var onQuadChanged: ((Quadrilateral) -> Void)?

    override func prepareForReuse() {
        super.prepareForReuse()

        guard let controller = cropController else { return }

        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()

        cropController = nil
    }

    func configure(
        model: ScanPreviewModel,
        parent: UIViewController,
        isEditable: Bool,
        onQuadChanged: ((Quadrilateral) -> Void)? = nil
    ) {
        parentVC = parent
        self.onQuadChanged = onQuadChanged

        guard let frame = model.frames.first,
              let image = frame.original ?? frame.preview else { return }

        let controller = DocumentCropperViewController(
            cropperModel: DocumentCropperModel(
                image: image,
                autoQuad: frame.quad
            )
        )
        
        controller.onQuadChanged = { [weak self] quad in
            self?.onQuadChanged?(quad)
        }

        cropController = controller
        
        controller.setEditable(isEditable)
        controller.setBackgroundColor(UIColor(.bg(.main)))

        parent.addChild(controller)

        controller.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])

        controller.didMove(toParent: parent)
    }
    
    func setEditable(_ editable: Bool) {
        cropController?.setEditable(editable)
    }
}
