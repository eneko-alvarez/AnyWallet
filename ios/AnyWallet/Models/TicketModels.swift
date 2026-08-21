import Foundation
import UIKit

struct TicketFields: Codable, Equatable {
    var title: String
    var issuer: String
    var origin: String
    var destination: String
    var passenger: String
    var reference: String
    var relevantDate: Date?

    static let empty = TicketFields(
        title: "",
        issuer: "",
        origin: "",
        destination: "",
        passenger: "",
        reference: "",
        relevantDate: nil
    )
}

struct QRCodeCandidate: Identifiable {
    let id: String
    let page: Int
    let payload: Data
    let readableValue: String?
    let preview: UIImage

    var byteLength: Int { payload.count }
}

struct TicketAnalysis {
    let filename: String
    let pageCount: Int
    let fields: TicketFields
    let qrCandidates: [QRCodeCandidate]
    let warnings: [String]
}

struct PassDraft: Encodable {
    let title: String
    let issuer: String
    let origin: String
    let destination: String
    let passenger: String
    let reference: String
    let relevantDate: Date?
    let qrPayloadBase64: String
    let backgroundColor: String
    let sourceFilename: String

    enum CodingKeys: String, CodingKey {
        case title, issuer, origin, destination, passenger, reference
        case relevantDate, qrPayloadBase64, backgroundColor, sourceFilename
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(issuer, forKey: .issuer)
        try container.encode(origin, forKey: .origin)
        try container.encode(destination, forKey: .destination)
        try container.encode(passenger, forKey: .passenger)
        try container.encode(reference, forKey: .reference)
        if let relevantDate {
            try container.encode(relevantDate, forKey: .relevantDate)
        } else {
            try container.encodeNil(forKey: .relevantDate)
        }
        try container.encode(qrPayloadBase64, forKey: .qrPayloadBase64)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(sourceFilename, forKey: .sourceFilename)
    }
}

struct PendingWalletPass: Identifiable {
    let id = UUID()
    let data: Data
}

enum AnyWalletError: LocalizedError {
    case invalidPDF
    case pdfTooLarge
    case tooManyPages
    case passwordProtected
    case noQRCode
    case invalidServerResponse
    case walletUnavailable
    case invalidPass
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidPDF: "El archivo no es un PDF válido."
        case .pdfTooLarge: "El PDF supera el límite de 15 MB."
        case .tooManyPages: "El PDF supera el límite de 12 páginas."
        case .passwordProtected: "El PDF está protegido con contraseña."
        case .noQRCode: "No se ha encontrado un código QR legible."
        case .invalidServerResponse: "La respuesta del servidor no es válida."
        case .walletUnavailable: "Este dispositivo no permite añadir pases a Wallet."
        case .invalidPass: "Apple Wallet ha rechazado el pase firmado."
        case .server(let message): message
        }
    }
}
