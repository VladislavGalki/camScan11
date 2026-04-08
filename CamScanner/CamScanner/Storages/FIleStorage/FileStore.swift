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

    @discardableResult
    func savePNG(data: Data, folder: String, fileName: String) throws -> URL {
        try ensureRootFolder()

        let fm = FileManager.default
        let folderURL = rootURL.appendingPathComponent(folder, isDirectory: true)
        if !fm.fileExists(atPath: folderURL.path) {
            try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        let fileURL = folderURL.appendingPathComponent(fileName)

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
    
    func documentFolderSize(docID: UUID) -> Int64 {
        let folder = rootURL.appendingPathComponent(docID.uuidString)
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        var total: Int64 = 0

        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }

        return total
    }
}

extension FileStore {
    func relativePath(fromAbsolute url: URL) -> String {
        let root = rootURL.path
        let full = url.path
        if full.hasPrefix(root + "/") {
            return String(full.dropFirst(root.count + 1)) // без ведущего "/"
        }
        return full
    }

    func url(forRelativePath rel: String) -> URL {
        if rel.hasPrefix("/") {
            return URL(fileURLWithPath: rel)
        }
        return rootURL.appendingPathComponent(rel)
    }
    
    func deleteFileIfExists(atPath path: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return }
        try? fm.removeItem(atPath: path)
    }

    func deleteFolderIfExists(at url: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        try? fm.removeItem(at: url)
    }
}
