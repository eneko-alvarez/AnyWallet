import CryptoKit
import DeviceCheck
import Foundation
import Security

actor AppAttestClient {
    struct Authorization {
        let challenge: String
        let keyIdentifier: String?
        let assertion: String?
    }

    private let baseURL: URL
    private let session: URLSession
    private let isRequired: Bool
    private let service = DCAppAttestService.shared
    private let keyDefaultsKey = "AppAttestKeyIdentifier"

    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        session: URLSession = .shared,
        isRequired: Bool = AppConfiguration.appAttestRequired
    ) {
        self.baseURL = baseURL
        self.session = session
        self.isRequired = isRequired
    }

    func authorize(payloadBuilder: (String) throws -> Data) async throws -> (Data, Authorization) {
        guard isRequired else {
            let challenge = try randomChallenge()
            return (try payloadBuilder(challenge), Authorization(challenge: challenge, keyIdentifier: nil, assertion: nil))
        }
        guard baseURL.scheme == "https" else {
            throw AnyWalletError.server(L10n.text("La conexión segura con el servicio no está configurada."))
        }
        let keyIdentifier = try await registeredKeyIdentifier()
        let challenge = try await requestChallenge()
        let payload = try payloadBuilder(challenge)
        let assertion = try await service.generateAssertion(
            keyIdentifier,
            clientDataHash: Data(SHA256.hash(data: payload))
        )
        return (
            payload,
            Authorization(
                challenge: challenge,
                keyIdentifier: keyIdentifier,
                assertion: assertion.base64EncodedString()
            )
        )
    }

    func invalidateKey() {
        UserDefaults.standard.removeObject(forKey: keyDefaultsKey)
    }

    private func registeredKeyIdentifier() async throws -> String {
        if let keyIdentifier = UserDefaults.standard.string(forKey: keyDefaultsKey) {
            return keyIdentifier
        }
        guard service.isSupported else {
            throw AnyWalletError.server(L10n.text("Este dispositivo no permite verificar la integridad de la app."))
        }

        let challenge = try await requestChallenge()
        let keyIdentifier = try await service.generateKey()
        let challengeHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestation = try await service.attestKey(keyIdentifier, clientDataHash: challengeHash)
        let body = try JSONEncoder().encode(AttestationRequest(
            challenge: challenge,
            keyId: keyIdentifier,
            attestation: attestation.base64EncodedString()
        ))
        var request = URLRequest(url: baseURL.appending(path: "v1/attest"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 204 else {
            throw AnyWalletError.server(L10n.text("No se ha podido verificar esta instalación de la app."))
        }
        UserDefaults.standard.set(keyIdentifier, forKey: keyDefaultsKey)
        return keyIdentifier
    }

    private func requestChallenge() async throws -> String {
        var request = URLRequest(url: baseURL.appending(path: "v1/attest/challenge"))
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let challenge = try? JSONDecoder().decode(ChallengeResponse.self, from: data).challenge else {
            throw AnyWalletError.server(L10n.text("No se ha podido iniciar la conexión segura con el servicio."))
        }
        return challenge
    }

    private func randomChallenge() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw AnyWalletError.server(L10n.text("No se ha podido preparar la solicitud."))
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct ChallengeResponse: Decodable {
    let challenge: String
}

private struct AttestationRequest: Encodable {
    let challenge: String
    let keyId: String
    let attestation: String
}
