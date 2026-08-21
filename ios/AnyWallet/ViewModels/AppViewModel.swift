import Foundation
import PassKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var analysis: TicketAnalysis?
    @Published var fields = TicketFields.empty
    @Published var selectedQRCodeID: String?
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

    var selectedQRCode: QRCodeCandidate? {
        analysis?.qrCandidates.first { $0.id == selectedQRCodeID }
    }

    var canCreatePass: Bool {
        selectedQRCode != nil && !fields.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreatingPass
    }

    func importPDF(from url: URL) {
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
                analysis = result
                fields = result.fields
                selectedQRCodeID = result.qrCandidates.first?.id
                passColor = PassColor.choices[0]
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func createPass() {
        guard let analysis, let qrCode = selectedQRCode else { return }
        guard PKAddPassesViewController.canAddPasses() else {
            errorMessage = AnyWalletError.walletUnavailable.localizedDescription
            return
        }

        isCreatingPass = true
        errorMessage = nil
        let draft = PassDraft(
            title: fields.title.trimmingCharacters(in: .whitespacesAndNewlines),
            issuer: fields.issuer,
            origin: fields.origin,
            destination: fields.destination,
            passenger: fields.passenger,
            reference: fields.reference,
            relevantDate: fields.relevantDate,
            qrPayloadBase64: qrCode.payload.base64EncodedString(),
            backgroundColor: passColor.cssValue,
            sourceFilename: analysis.filename
        )

        Task {
            defer { isCreatingPass = false }
            do {
                let data = try await signingClient.createPass(from: draft)
                _ = try PKPass(data: data)
                pendingWalletPass = PendingWalletPass(data: data)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func reset() {
        analysis = nil
        fields = .empty
        selectedQRCodeID = nil
        passColor = PassColor.choices[0]
        errorMessage = nil
        pendingWalletPass = nil
    }
}
