import CryptoKit
import Foundation
import PDFKit
import UIKit
import Vision

actor TicketAnalyzer {
    private let maxPDFBytes = 15 * 1024 * 1024
    private let maxPages = 12
    private let maxQRBytes = 4_096

    func analyze(url: URL) async throws -> TicketAnalysis {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > maxPDFBytes {
            throw AnyWalletError.pdfTooLarge
        }
        guard let document = PDFDocument(url: url) else {
            throw AnyWalletError.invalidPDF
        }
        guard !document.isLocked else {
            throw AnyWalletError.passwordProtected
        }
        guard document.pageCount <= maxPages else {
            throw AnyWalletError.tooManyPages
        }

        var pageTexts: [String] = []
        var candidatesByID: [String: QRCodeCandidate] = [:]

        for pageIndex in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: pageIndex) else { continue }
            var pageText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            for targetWidth in [1_600.0, 2_800.0] {
                try Task.checkCancellation()
                guard let image = render(page: page, targetWidth: targetWidth),
                      let cgImage = image.cgImage else { continue }

                for observation in try detectQRCodes(in: cgImage) {
                    guard let payload = observation.payloadData ?? observation.payloadStringValue?.data(using: .utf8),
                          !payload.isEmpty,
                          payload.count <= maxQRBytes,
                          let preview = QRCodeRenderer.image(for: payload) else { continue }
                    let id = digest(payload)
                    if candidatesByID[id] == nil {
                        candidatesByID[id] = QRCodeCandidate(
                            id: id,
                            page: pageIndex + 1,
                            payload: payload,
                            readableValue: readableValue(payload),
                            preview: preview
                        )
                    }
                }

                if pageText.count < 20, targetWidth == 2_800 {
                    pageText = try recognizeText(in: cgImage)
                }
            }
            pageTexts.append(pageText)
        }

        let combinedText = pageTexts.joined(separator: "\n")
        let candidates = candidatesByID.values.sorted {
            $0.page == $1.page ? $0.id < $1.id : $0.page < $1.page
        }
        var warnings: [String] = []
        if candidates.isEmpty {
            warnings.append("No se ha detectado ningún código QR en el PDF.")
        }
        if candidates.count > 1 {
            warnings.append("Hay varios códigos QR. Revisa y elige el que valida el billete.")
        }
        if combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("No se ha podido extraer texto. Completa los datos manualmente.")
        }

        return TicketAnalysis(
            filename: url.lastPathComponent,
            pageCount: document.pageCount,
            fields: FieldExtractor.extract(filename: url.lastPathComponent, text: combinedText),
            qrCandidates: candidates,
            warnings: warnings
        )
    }

    private func render(page: PDFPage, targetWidth: CGFloat) -> UIImage? {
        let bounds = page.bounds(for: .cropBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let ratio = bounds.height / bounds.width
        let size = CGSize(width: targetWidth, height: min(targetWidth * ratio, 4_000))
        return page.thumbnail(of: size, for: .cropBox)
    }

    private func detectQRCodes(in image: CGImage) throws -> [VNBarcodeObservation] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try handler.perform([request])
        return request.results ?? []
    }

    private func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-ES", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try handler.perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private func readableValue(_ data: Data) -> String? {
        guard let value = String(data: data, encoding: .utf8),
              value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) || [9, 10, 13].contains($0.value) }) else {
            return nil
        }
        return String(value.prefix(240))
    }
}
