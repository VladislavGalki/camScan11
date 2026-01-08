import Foundation
import UIKit

final class FileStore {

    static let shared = FileStore()
    private init() {}

    enum FileStoreError: Error {
        case failedToEncodeJPEG
        case failedToCreateFolder
        case failedToWrite
        case fileNotFound
    }

    // Папка: Library/Application Support/YourApp/Documents/
    private let rootFolderName = "Documents"

    private var appSupportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
    }

    private var rootURL: URL {
        appSupportURL.appendingPathComponent(rootFolderName, isDirectory: true)
    }

    /// Создаёт папку если надо
    private func ensureRootFolder() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: rootURL.path) {
            do {
                try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
            } catch {
                throw FileStoreError.failedToCreateFolder
            }
        }
    }

    /// Сохраняем страницу как JPEG: Documents/<docID>/<pageID>.jpg
    @discardableResult
    func saveJPEG(image: UIImage, docID: UUID, pageID: UUID, quality: CGFloat = 0.92) throws -> URL {
        try ensureRootFolder()

        let fm = FileManager.default
        let docFolder = rootURL.appendingPathComponent(docID.uuidString, isDirectory: true)
        if !fm.fileExists(atPath: docFolder.path) {
            do {
                try fm.createDirectory(at: docFolder, withIntermediateDirectories: true)
            } catch {
                throw FileStoreError.failedToCreateFolder
            }
        }

        guard let data = image.jpegData(compressionQuality: quality) else {
            throw FileStoreError.failedToEncodeJPEG
        }

        let fileURL = docFolder.appendingPathComponent("\(pageID.uuidString).jpg")

        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw FileStoreError.failedToWrite
        }

        // ✅ Не бэкапить (по желанию)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = fileURL
        try? mutableURL.setResourceValues(values)

        // ✅ File protection (шифрование, когда телефон заблокирован)
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)

        return fileURL
    }

    func loadImage(at url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteDocumentFolder(docID: UUID) {
        let fm = FileManager.default
        let docFolder = rootURL.appendingPathComponent(docID.uuidString, isDirectory: true)
        try? fm.removeItem(at: docFolder)
    }
}

extension FileStore {

    /// Удалить конкретный файл по path (если существует)
    func deleteFileIfExists(atPath path: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return }
        try? fm.removeItem(atPath: path)
    }

    /// Удалить папку документа по path (если существует)
    func deleteFolderIfExists(at url: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        try? fm.removeItem(at: url)
    }
}
