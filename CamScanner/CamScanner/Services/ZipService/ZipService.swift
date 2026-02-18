import Foundation
import ZIPFoundation

final class ZipService {
    static let shared = ZipService()
    private init() {}
    
    func zip(files: [URL], fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("zip")

        let archive = try Archive(url: url, accessMode: .create)

        for file in files {
            try archive.addEntry(
                with: file.lastPathComponent,
                fileURL: file
            )
        }

        return url
    }
}
