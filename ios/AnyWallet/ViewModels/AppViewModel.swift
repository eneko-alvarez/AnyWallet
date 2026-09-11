import Foundation
import PassKit
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var analysis: TicketAnalysis?
    @Published var fields = TicketFields.empty
    @Published var passKind: PassKind = .travel
    @Published var selectedBarcodeID: String?
    @Published var passColor = PassColor.choices[0]
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isCreatingPass = false
    @Published var errorMessage: String?
    @Published var pendingWalletPass: PendingWalletPass?
    @Published private(set) var isCustomMode = false
    @Published var customFields: [CustomPassField] = []
    @Published var customPhotoData: Data?
    @Published var photoAspect: PhotoAspect = .square
    @Published var customBarcodeValue = ""
    @Published var customBarcodeFormat: BarcodeFormat = .qr

    private let analyzer: TicketAnalyzer
    private let signingClient: SigningClient

    init(analyzer: TicketAnalyzer = TicketAnalyzer(), signingClient: SigningClient = SigningClient()) {
        self.analyzer = analyzer
        self.signingClient = signingClient
    }

    var selectedBarcode: BarcodeCandidate? {
        if isCustomMode {
            let value = customBarcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, let payload = value.data(using: .utf8),
                  let preview = BarcodeRenderer.image(for: payload, format: customBarcodeFormat) else { return nil }
            return BarcodeCandidate(
                id: "custom-barcode", page: 0, format: customBarcodeFormat,
                payload: payload, readableValue: value, preview: preview
            )
        }
        return analysis?.barcodeCandidates.first { $0.id == selectedBarcodeID }
    }

    var canCreatePass: Bool {
        let hasTitle = !fields.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let customCode = customBarcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidCode = selectedBarcode != nil
        let codeIsValid = isCustomMode ? (customCode.isEmpty || hasValidCode) : hasValidCode
        return hasTitle && codeIsValid && !isCreatingPass
    }

    func importFile(from url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        isAnalyzing = true
        errorMessage = nil

        Task {
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
                isAnalyzing = false
            }
            do {
                let result = try await analyzer.analyze(url: url)
                apply(result)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func importImage(data: Data, filename: String = "captura.png") {
        isAnalyzing = true
        errorMessage = nil

        Task {
            defer { isAnalyzing = false }
            do {
                let result = try await analyzer.analyze(imageData: data, filename: filename)
                apply(result)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func apply(_ result: TicketAnalysis) {
        isCustomMode = false
        analysis = result
        fields = result.fields
        passKind = result.suggestedPassKind
        selectedBarcodeID = result.barcodeCandidates.first?.id
        passColor = PassColor.choices[0]
    }

    func selectPassKind(_ kind: PassKind) {
        guard passKind != kind else { return }
        if kind == .membership {
            if fields.memberName.isEmpty { fields.memberName = fields.passenger }
            if fields.memberNumber.isEmpty { fields.memberNumber = fields.reference }
        } else if kind == .travel {
            if fields.passenger.isEmpty { fields.passenger = fields.memberName }
            if fields.reference.isEmpty { fields.reference = fields.memberNumber }
        }
        passKind = kind
    }

    func createPass() {
        let barcode = selectedBarcode
        let customCode = customBarcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!isCustomMode && barcode != nil) || (isCustomMode && (customCode.isEmpty || barcode != nil)) else { return }
        guard PKAddPassesViewController.canAddPasses() else {
            errorMessage = AnyWalletError.walletUnavailable.localizedDescription
            return
        }

        isCreatingPass = true
        errorMessage = nil
        let draft = PassDraft(
            passKind: passKind,
            title: fields.title.trimmingCharacters(in: .whitespacesAndNewlines),
            issuer: fields.issuer,
            origin: fields.origin,
            destination: fields.destination,
            passenger: fields.passenger,
            reference: fields.reference,
            memberName: fields.memberName,
            memberNumber: fields.memberNumber,
            relevantDate: fields.relevantDate,
            barcodeFormat: barcode?.format,
            barcodePayloadBase64: barcode?.payload.base64EncodedString(),
            backgroundColor: passColor.cssValue,
            customFields: isCustomMode ? customFields.filter {
                !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } : [],
            photoAspect: isCustomMode && customPhotoData != nil ? photoAspect : nil,
            photoBase64: isCustomMode ? customPhotoData?.base64EncodedString() : nil
        )

        Task {
            defer { isCreatingPass = false }
            do {
                let data = try await signingClient.createPass(from: draft)
                do {
                    _ = try PKPass(data: data)
                } catch {
                    let error = error as NSError
                    throw AnyWalletError.server(
                        "Validar en Wallet: \(error.domain) \(error.code) · \(error.localizedDescription)"
                    )
                }
                pendingWalletPass = PendingWalletPass(data: data)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func reset() {
        analysis = nil
        fields = .empty
        passKind = .travel
        selectedBarcodeID = nil
        passColor = PassColor.choices[0]
        errorMessage = nil
        pendingWalletPass = nil
        isCustomMode = false
        customFields = []
        customPhotoData = nil
        photoAspect = .square
        customBarcodeValue = ""
        customBarcodeFormat = .qr
    }

    func startCustomPass() {
        reset()
        isCustomMode = true
        passKind = .custom
        fields.title = "Mi pase"
        customFields = [
            CustomPassField(label: "Nombre", value: ""),
            CustomPassField(label: "Identificador", value: ""),
        ]
    }

    func addCustomField() {
        guard customFields.count < 4 else { return }
        customFields.append(CustomPassField(label: "Campo \(customFields.count + 1)", value: ""))
    }

    func removeCustomField(id: UUID) {
        customFields.removeAll { $0.id == id }
    }

    func setCustomPhoto(data: Data) throws {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw AnyWalletError.invalidDocument
        }
        guard let prepared = image.anyWalletJPEG(maxDimension: 1_200, maxBytes: 280_000) else {
            throw AnyWalletError.invalidDocument
        }
        customPhotoData = prepared
    }
}

private extension UIImage {
    func anyWalletJPEG(maxDimension: CGFloat, maxBytes: Int) -> Data? {
        for dimension in [maxDimension, 900, 700] {
            let scale = min(1, dimension / max(size.width, size.height))
            let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
                UIColor.white.setFill()
                UIRectFill(CGRect(origin: .zero, size: target))
                draw(in: CGRect(origin: .zero, size: target))
            }
            for quality in stride(from: CGFloat(0.84), through: 0.32, by: -0.08) {
                if let data = rendered.jpegData(compressionQuality: quality), data.count <= maxBytes { return data }
            }
        }
        return nil
    }
}
