import UIKit
import Photos

final class SaveToPhotosActivity: UIActivity {

    private var imagesToSave: [UIImage] = []

    override class var activityCategory: UIActivity.Category { .action }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.yourapp.saveToPhotos")
    }

    override var activityTitle: String? { "Сохранить в Фото" }

    override var activityImage: UIImage? {
        UIImage(systemName: "square.and.arrow.down")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return activityItems.contains { $0 is UIImage }
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        self.imagesToSave = activityItems.compactMap { $0 as? UIImage }
    }

    override func perform() {
        guard !imagesToSave.isEmpty else {
            activityDidFinish(false)
            return
        }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { self.activityDidFinish(false) }
                return
            }

            var remaining = self.imagesToSave.count
            var anyFailed = false

            for img in self.imagesToSave {
                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                remaining -= 1
                if remaining == 0 {
                    DispatchQueue.main.async { self.activityDidFinish(!anyFailed) }
                }
            }
        }
    }
}
