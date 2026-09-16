import Foundation
import UIKit

enum PassKind: String, Codable, CaseIterable, Identifiable {
    case travel
    case membership
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .travel: L10n.text("Viaje")
        case .membership: L10n.text("Membresía")
        case .custom: L10n.text("Personalizado")
        }
    }
}

enum PhotoAspect: String, Codable, CaseIterable, Identifiable {
    case square
    case portrait
    case landscape
    case wide

    var id: Self { self }

    var title: String {
        switch self {
        case .square: "1:1"
        case .portrait: "3:4"
        case .landscape: "4:3"
        case .wide: "16:9"
        }
    }

    var ratio: CGFloat {
        switch self {
        case .square: 1
        case .portrait: 3 / 4
        case .landscape: 4 / 3
        case .wide: 16 / 9
        }
    }
}

struct CustomPassField: Codable, Equatable, Identifiable {
    var id = UUID()
    var label: String
    var value: String

    enum CodingKeys: String, CodingKey { case label, value }
}

enum BarcodeFormat: String, Codable {
    case qr
    case code128
    case pdf417
    case aztec

    var title: String {
        switch self {
        case .qr: "QR"
        case .code128: "Code 128"
        case .pdf417: "PDF417"
        case .aztec: "Aztec"
        }
    }
}

struct TicketFields: Codable, Equatable {
    var title: String
    var issuer: String
    var origin: String
    var destination: String
    var passenger: String
    var reference: String
    var memberName: String
    var memberNumber: String
    var relevantDate: Date?

    static let empty = TicketFields(
        title: "",
        issuer: "",
        origin: "",
        destination: "",
        passenger: "",
        reference: "",
        memberName: "",
        memberNumber: "",
        relevantDate: nil
    )
}

struct BarcodeCandidate: Identifiable {
    let id: String
    let page: Int
    let format: BarcodeFormat
    let payload: Data
    let readableValue: String?
    let preview: UIImage

    var byteLength: Int { payload.count }
}

struct TicketAnalysis {
    let filename: String
    let pageCount: Int
    let fields: TicketFields
    let suggestedPassKind: PassKind
    let barcodeCandidates: [BarcodeCandidate]
    let warnings: [String]
}

struct PassDraft: Encodable {
    let passKind: PassKind
    let title: String
    let issuer: String
    let origin: String
    let destination: String
    let passenger: String
    let reference: String
    let memberName: String
    let memberNumber: String
    let relevantDate: Date?
    let barcodeFormat: BarcodeFormat?
    let barcodePayloadBase64: String?
    let backgroundColor: String
    let customFields: [CustomPassField]
    let photoAspect: PhotoAspect?
    let photoBase64: String?

    enum CodingKeys: String, CodingKey {
        case passKind, title, issuer, origin, destination, passenger, reference
        case memberName, memberNumber, relevantDate, barcodeFormat, barcodePayloadBase64, backgroundColor
        case customFields, photoAspect, photoBase64
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(passKind, forKey: .passKind)
        try container.encode(title, forKey: .title)
        try container.encode(issuer, forKey: .issuer)
        try container.encode(origin, forKey: .origin)
        try container.encode(destination, forKey: .destination)
        try container.encode(passenger, forKey: .passenger)
        try container.encode(reference, forKey: .reference)
        try container.encode(memberName, forKey: .memberName)
        try container.encode(memberNumber, forKey: .memberNumber)
        if let relevantDate {
            try container.encode(relevantDate, forKey: .relevantDate)
        } else {
            try container.encodeNil(forKey: .relevantDate)
        }
        try container.encodeIfPresent(barcodeFormat, forKey: .barcodeFormat)
        try container.encodeIfPresent(barcodePayloadBase64, forKey: .barcodePayloadBase64)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(customFields, forKey: .customFields)
        try container.encodeIfPresent(photoAspect, forKey: .photoAspect)
        try container.encodeIfPresent(photoBase64, forKey: .photoBase64)
    }
}

struct PendingWalletPass: Identifiable {
    let id = UUID()
    let data: Data
}

enum AnyWalletError: LocalizedError {
    case invalidDocument
    case fileTooLarge
    case tooManyPages
    case passwordProtected
    case noBarcode
    case invalidServerResponse
    case walletUnavailable
    case invalidPass
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidDocument: L10n.text("El archivo no es un PDF o una imagen válida.")
        case .fileTooLarge: L10n.text("El archivo supera el límite de 15 MB.")
        case .tooManyPages: L10n.text("El PDF supera el límite de 12 páginas.")
        case .passwordProtected: L10n.text("El PDF está protegido con contraseña.")
        case .noBarcode: L10n.text("No se ha encontrado un código compatible legible.")
        case .invalidServerResponse: L10n.text("La respuesta del servidor no es válida.")
        case .walletUnavailable: L10n.text("Este dispositivo no permite añadir pases a Wallet.")
        case .invalidPass: L10n.text("Apple Wallet ha rechazado el pase firmado.")
        case .server(let message): message
        }
    }
}
