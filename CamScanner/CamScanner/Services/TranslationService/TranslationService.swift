import Foundation

enum TranslationService {

    enum TranslationError: Error {
        case invalidURL
        case invalidResponse
        case requestFailed
        case server(message: String)
    }

    static func translate(
        text: String,
        to targetLanguage: String,
        sourceLanguage: String? = nil
    ) async throws -> String {
        guard let url = URL(string: "https://pdfaiapp.com/api/v1/translate") else {
            throw TranslationError.invalidURL
        }

        let requestBody = TranslationRequest(
            text: text,
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(appLocaleHeaderValue, forHTTPHeaderField: "app-locale")
        request.setValue(appVersionHeaderValue, forHTTPHeaderField: "app-verison")
        request.setValue(appVersionHeaderValue, forHTTPHeaderField: "app-version")
        request.setValue(appPackageHeaderValue, forHTTPHeaderField: "app-package")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        let decoded = try? JSONDecoder().decode(TranslationResponse.self, from: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = decoded?.error?.message
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw TranslationError.server(message: errorMessage)
        }

        guard let decoded, decoded.success, let translatedText = decoded.data?.translatedText else {
            throw TranslationError.requestFailed
        }

        return translatedText
    }

    private static var appLocaleHeaderValue: String {
        let code = Locale.current.language.languageCode?.identifier
            ?? Locale.current.languageCode
        return code?.lowercased() ?? "en"
    }

    private static var appVersionHeaderValue: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        ?? "1.0.0"
    }

    private static var appPackageHeaderValue: String {
        Bundle.main.bundleIdentifier ?? "com.pdfaiapp.mobile"
    }
}

private struct TranslationRequest: Encodable {
    let text: String
    let targetLanguage: String
    let sourceLanguage: String?

    enum CodingKeys: String, CodingKey {
        case text
        case targetLanguage = "target_language"
        case sourceLanguage = "source_language"
    }
}

private struct TranslationResponse: Decodable {
    let success: Bool
    let data: TranslationData?
    let error: TranslationAPIError?

    struct TranslationData: Decodable {
        let translatedText: String

        enum CodingKeys: String, CodingKey {
            case translatedText = "translated_text"
        }
    }

    struct TranslationAPIError: Decodable {
        let code: String?
        let message: String?
    }
}
