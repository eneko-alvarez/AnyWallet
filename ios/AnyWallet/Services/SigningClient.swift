import Foundation

actor SigningClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = AppConfiguration.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func createPass(from draft: PassDraft) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: "v1/passes"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.anyWallet.encode(draft)

        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
        let result = try JSONDecoder().decode(PassCreationResponse.self, from: responseData)
        guard let downloadURL = URL(string: result.downloadURL) else {
            throw AnyWalletError.invalidServerResponse
        }

        let (passData, passResponse) = try await session.data(from: downloadURL)
        try validate(response: passResponse, data: passData)
        guard !passData.isEmpty else { throw AnyWalletError.invalidServerResponse }
        return passData
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AnyWalletError.invalidServerResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = try? JSONDecoder().decode(ServerErrorResponse.self, from: data)
            throw AnyWalletError.server(body?.message ?? "Error del servidor (\(http.statusCode)).")
        }
    }
}

private struct PassCreationResponse: Decodable {
    let downloadURL: String

    enum CodingKeys: String, CodingKey {
        case downloadURL = "downloadUrl"
    }
}

private struct ServerErrorResponse: Decodable {
    let message: String
}

private extension JSONEncoder {
    static var anyWallet: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
