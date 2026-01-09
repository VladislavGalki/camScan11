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

        if !fm.fileExists(atPath: appSupportURL.path) {
            try fm.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        }

        if !fm.fileExists(atPath: rootURL.path) {
            do {
                try fm.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw FileStoreError.failedToCreateFolder
            }
        }
    }

    /// Сохраняем страницу как JPEG: Documents/<docID>/<pageID>.jpg
    @discardableResult
    func saveJPEG(image: UIImage, docID: UUID, pageID: UUID, fileName: String, quality: CGFloat = 0.92) throws -> URL {
        try ensureRootFolder()

        let fm = FileManager.default
        let docFolder = rootURL.appendingPathComponent(docID.uuidString, isDirectory: true)
        if !fm.fileExists(atPath: docFolder.path) {
            try fm.createDirectory(at: docFolder, withIntermediateDirectories: true)
        }

        guard let data = image.jpegData(compressionQuality: quality) else {
            throw FileStoreError.failedToEncodeJPEG
        }

        let fileURL = docFolder.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw FileStoreError.failedToWrite
        }

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = fileURL
        try? mutableURL.setResourceValues(values)

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

    func relativePath(fromAbsolute url: URL) -> String {
        let root = rootURL.path
        let full = url.path
        if full.hasPrefix(root + "/") {
            return String(full.dropFirst(root.count + 1)) // без ведущего "/"
        }
        return full // fallback
    }

    func url(forRelativePath rel: String) -> URL {
        // если вдруг в базе лежит абсолютный путь — поддержим
        if rel.hasPrefix("/") {
            return URL(fileURLWithPath: rel)
        }
        return rootURL.appendingPathComponent(rel)
    }
    
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
