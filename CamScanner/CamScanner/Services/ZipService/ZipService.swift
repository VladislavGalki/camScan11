import Foundation
import ZIPFoundation

final class ZipService {
    init() {}

    func zip(files: [URL], fileName: String) throws -> URL {
        let fm = FileManager.default

        let zipURL = fm.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("zip")

        if fm.fileExists(atPath: zipURL.path) {
            try fm.removeItem(at: zipURL)
        }

        let archive = try Archive(url: zipURL, accessMode: .create)

        for file in files {
            guard fm.fileExists(atPath: file.path) else {
                continue
            }

            try archive.addEntry(
                with: file.lastPathComponent,
                fileURL: file,
                compressionMethod: .deflate
            )
        }

        return zipURL
    }
}
