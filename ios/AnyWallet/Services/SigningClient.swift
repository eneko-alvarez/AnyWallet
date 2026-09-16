import Foundation

actor SigningClient {
    private let baseURL: URL
    private let session: URLSession
    private let appAttestClient: AppAttestClient

    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        session: URLSession = .shared,
        appAttestClient: AppAttestClient? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.appAttestClient = appAttestClient ?? AppAttestClient(baseURL: baseURL, session: session)
    }

    func createPass(from draft: PassDraft) async throws -> Data {
        try await createPass(from: draft, canRetryAttestation: true)
    }

    private func createPass(from draft: PassDraft, canRetryAttestation: Bool) async throws -> Data {
        let creationURL = baseURL.appending(path: "v1/passes")
        let (body, authorization) = try await appAttestClient.authorize { challenge in
            try JSONEncoder.anyWallet.encode(PassCreationRequest(challenge: challenge, draft: draft))
        }
        var request = URLRequest(url: creationURL)
        request.httpMethod = "POST"
        request.setValue(L10n.language, forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        if let keyIdentifier = authorization.keyIdentifier,
           let assertion = authorization.assertion {
            request.setValue(keyIdentifier, forHTTPHeaderField: "X-App-Attest-Key-Id")
            request.setValue(assertion, forHTTPHeaderField: "X-App-Attest-Assertion")
        }

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw AnyWalletError.server(L10n.format("No se ha podido conectar con el servicio: %@", diagnostic(for: error)))
        }
        if let http = response as? HTTPURLResponse,
           http.statusCode == 401,
           authorization.keyIdentifier != nil,
           canRetryAttestation {
            await appAttestClient.invalidateKey()
            return try await createPass(from: draft, canRetryAttestation: false)
        }
        try validate(response: response, data: responseData, operation: L10n.text("Crear el pase"))
        let result: PassCreationResponse
        do {
            result = try JSONDecoder().decode(PassCreationResponse.self, from: responseData)
        } catch {
            throw AnyWalletError.server(L10n.format("Crear el pase: respuesta JSON inválida (%@).", diagnostic(for: error)))
        }
        guard let downloadURL = URL(string: result.downloadURL) else {
            throw AnyWalletError.server(L10n.text("Crear el pase: el servidor devolvió una URL de descarga inválida."))
        }

        let passData: Data
        let passResponse: URLResponse
        do {
            var downloadRequest = URLRequest(url: downloadURL)
            downloadRequest.setValue(L10n.language, forHTTPHeaderField: "Accept-Language")
            (passData, passResponse) = try await session.data(for: downloadRequest)
        } catch {
            throw AnyWalletError.server(L10n.format("No se ha podido descargar el pase: %@", diagnostic(for: error)))
        }
        try validate(response: passResponse, data: passData, operation: L10n.text("Descargar el pase"))
        guard !passData.isEmpty else {
            throw AnyWalletError.server(L10n.text("Descargar el pase: el servidor devolvió un archivo vacío."))
        }
        return passData
    }

    private func validate(response: URLResponse, data: Data, operation: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AnyWalletError.server(L10n.format("%@: la respuesta no es HTTP.", operation))
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = try? JSONDecoder().decode(ServerErrorResponse.self, from: data)
            let code = body?.code.map { " · \($0)" } ?? ""
            let details = body?.details?.map { "\($0.field): \($0.message)" }.joined(separator: "; ")
            let detailSuffix = details.map { " · \($0)" } ?? ""
            let message = body?.message ?? L10n.text("El servidor no devolvió un mensaje de error.")
            throw AnyWalletError.server("\(operation): HTTP \(http.statusCode)\(code) · \(message)\(detailSuffix)")
        }
    }

    private func diagnostic(for error: Error) -> String {
        let error = error as NSError
        return "\(error.domain) \(error.code): \(error.localizedDescription)"
    }
}

private struct PassCreationRequest: Encodable {
    let challenge: String
    let draft: PassDraft
}

private struct PassCreationResponse: Decodable {
    let downloadURL: String

    enum CodingKeys: String, CodingKey {
        case downloadURL = "downloadUrl"
    }
}

private struct ServerErrorResponse: Decodable {
    let code: String?
    let message: String
    let details: [ServerErrorDetail]?
}

private struct ServerErrorDetail: Decodable {
    let field: String
    let message: String
}

private extension JSONEncoder {
    static var anyWallet: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
