import UIKit
import Vision
import NaturalLanguage

struct OCRResult {
    let text: String
}

let ocrLanguages: [String] = [
    // English
    "en-US",

    // Chinese
    "zh-Hans", // Simplified (zh-s)
    "zh-Hant", // Traditional (zh-t)

    // Asian
    "ja-JP",
    "ko-KR",
    "th-TH",
    "vi-VN",

    // European (Latin)
    "fr-FR",
    "es-ES",
    "pt-PT",
    "de-DE",
    "it-IT",
    "nl-NL",
    "sv-SE",
    "fi-FI",
    "da-DK",
    "nb-NO",
    "hu-HU",
    "pl-PL",
    "cs-CZ",
    "sk-SK",
    "sl-SI",
    "sr-Latn-RS",
    "ca-ES",
    "tr-TR",
    "uk-UA",

    // Cyrillic
    "ru-RU",

    // Middle East
    "ar-SA",
    "he-IL",
    "fa-IR",
    "ur-PK",

    // South Asia
    "hi-IN",
    "bn-IN",
    "ta-IN",
    "ne-NP",
    "sa-IN",

    // Southeast Asia
    "id-ID",
    "tl-PH",

    // Africa
    "af-ZA",

    // Central Asia
    "uz-UZ",

    // Greek
    "el-GR"
]

final class OCRService {
    init() {}

    enum OCRError: Error {
        case noCGImage
        case failed
    }

    func detectLanguage(in image: UIImage) async throws -> String? {
        let result = try await recognizeText(in: image)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        return language.rawValue
    }

    func recognizeText(in image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage ?? image.normalizedUp().cgImage else {
            throw OCRError.noCGImage
        }

        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err {
                    cont.resume(throwing: err)
                    return
                }

                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    cont.resume(throwing: OCRError.failed)
                    return
                }

                let lines: [String] = observations.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }

                cont.resume(returning: OCRResult(text: lines.joined(separator: "\n")))
            }

            request.recognitionLanguages = ocrLanguages
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.02

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
