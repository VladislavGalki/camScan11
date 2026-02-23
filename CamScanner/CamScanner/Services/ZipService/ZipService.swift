import Foundation
import ZIPFoundation

final class ZipService {
    static let shared = ZipService()
    private init() {}

    func zip(files: [URL], fileName: String) throws -> URL {
        let fm = FileManager.default

        let zipURL = fm.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("zip")

        if fm.fileExists(atPath: zipURL.path) {
            do {
                try fm.removeItem(at: zipURL)
            } catch {
                throw error
            }
        }

        let archive = try Archive(url: zipURL, accessMode: .create)

        for file in files {
            guard fm.fileExists(atPath: file.path) else {
                continue
            }

            do {
                try archive.addEntry(
                    with: file.lastPathComponent,
                    fileURL: file,
                    compressionMethod: .deflate
                )
            } catch {
                throw error
            }
        }
        
        return zipURL
    }
}

enum ZipError: Error {
    case createFailed
}
