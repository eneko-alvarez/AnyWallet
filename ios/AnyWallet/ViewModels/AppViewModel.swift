import Foundation
import PassKit

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

    private let analyzer: TicketAnalyzer
    private let signingClient: SigningClient

    init(analyzer: TicketAnalyzer = TicketAnalyzer(), signingClient: SigningClient = SigningClient()) {
        self.analyzer = analyzer
        self.signingClient = signingClient
    }

    var selectedBarcode: BarcodeCandidate? {
        analysis?.barcodeCandidates.first { $0.id == selectedBarcodeID }
    }

    var canCreatePass: Bool {
        selectedBarcode != nil && !fields.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreatingPass
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
        } else {
            if fields.passenger.isEmpty { fields.passenger = fields.memberName }
            if fields.reference.isEmpty { fields.reference = fields.memberNumber }
        }
        passKind = kind
    }

    func createPass() {
        guard let barcode = selectedBarcode else { return }
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
            barcodeFormat: barcode.format,
            barcodePayloadBase64: barcode.payload.base64EncodedString(),
            backgroundColor: passColor.cssValue
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
    }
}
