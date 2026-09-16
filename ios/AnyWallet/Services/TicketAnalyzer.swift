import CryptoKit
import CoreImage
import Foundation
import ImageIO
import PDFKit
import UIKit
import UniformTypeIdentifiers
import Vision

actor TicketAnalyzer {
    private let maxInputBytes = 15 * 1024 * 1024
    private let maxImagePixels = 40_000_000
    private let maxPages = 12
    private let maxBarcodeBytes = 4_096

    private struct DetectedBarcode {
        let format: BarcodeFormat
        let payload: Data
    }

    func analyze(url: URL) async throws -> TicketAnalysis {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > maxInputBytes {
            throw AnyWalletError.fileTooLarge
        }

        let contentType = UTType(filenameExtension: url.pathExtension)
        if contentType?.conforms(to: .pdf) == true {
            guard let document = PDFDocument(url: url) else {
                throw AnyWalletError.invalidDocument
            }
            return try analyze(document: document, filename: url.lastPathComponent)
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try await analyze(imageData: data, filename: url.lastPathComponent)
    }

    func analyze(imageData: Data, filename: String) async throws -> TicketAnalysis {
        guard imageData.count <= maxInputBytes else { throw AnyWalletError.fileTooLarge }
        guard let image = decodedImage(from: imageData) else { throw AnyWalletError.invalidDocument }

        try Task.checkCancellation()
        let barcodes = detectBarcodes(in: image)
        let candidates = barcodes.compactMap { candidate(for: $0, page: 1) }
        let text = (try? recognizeText(in: image)) ?? ""
        return result(filename: filename, pageCount: 1, texts: [text], candidates: candidates)
    }

    private func analyze(document: PDFDocument, filename: String) throws -> TicketAnalysis {
        guard !document.isLocked else {
            throw AnyWalletError.passwordProtected
        }
        guard document.pageCount <= maxPages else {
            throw AnyWalletError.tooManyPages
        }

        var pageTexts: [String] = []
        var candidatesByID: [String: BarcodeCandidate] = [:]

        for pageIndex in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: pageIndex) else { continue }
            var pageText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            for targetWidth in [1_600.0, 2_800.0] {
                try Task.checkCancellation()
                guard let image = render(page: page, targetWidth: targetWidth),
                      let cgImage = image.cgImage else { continue }

                for barcode in detectBarcodes(in: cgImage) {
                    if let candidate = candidate(for: barcode, page: pageIndex + 1), candidatesByID[candidate.id] == nil {
                        candidatesByID[candidate.id] = candidate
                    }
                }

                if pageText.count < 20, targetWidth == 2_800 {
                    pageText = (try? recognizeText(in: cgImage)) ?? pageText
                }
            }
            pageTexts.append(pageText)
        }

        return result(
            filename: filename,
            pageCount: document.pageCount,
            texts: pageTexts,
            candidates: Array(candidatesByID.values)
        )
    }

    private func result(filename: String, pageCount: Int, texts: [String], candidates: [BarcodeCandidate]) -> TicketAnalysis {
        let combinedText = texts.joined(separator: "\n")
        let sortedCandidates = candidates.sorted {
            $0.page == $1.page ? $0.id < $1.id : $0.page < $1.page
        }
        var warnings: [String] = []
        if sortedCandidates.isEmpty {
            warnings.append(L10n.text("No se ha detectado ningún código QR o de barras compatible en el archivo."))
        }
        if sortedCandidates.count > 1 {
            warnings.append(L10n.text("Hay varios códigos. Revisa y elige el que identifica el pase."))
        }
        if combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append(L10n.text("No se ha podido extraer texto. Completa los datos manualmente."))
        }

        let fields = FieldExtractor.extract(filename: filename, text: combinedText)
        return TicketAnalysis(
            filename: filename,
            pageCount: pageCount,
            fields: fields,
            suggestedPassKind: FieldExtractor.suggestedPassKind(filename: filename, text: combinedText, fields: fields),
            barcodeCandidates: sortedCandidates,
            warnings: warnings
        )
    }

    private func decodedImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              width <= maxImagePixels / height else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4_000
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func candidate(for barcode: DetectedBarcode, page: Int) -> BarcodeCandidate? {
        guard !barcode.payload.isEmpty,
              barcode.payload.count <= maxBarcodeBytes,
              let preview = BarcodeRenderer.image(for: barcode.payload, format: barcode.format) else { return nil }
        return BarcodeCandidate(
            id: digest(Data(barcode.format.rawValue.utf8) + barcode.payload),
            page: page,
            format: barcode.format,
            payload: barcode.payload,
            readableValue: readableValue(barcode.payload),
            preview: preview
        )
    }

    private func render(page: PDFPage, targetWidth: CGFloat) -> UIImage? {
        let bounds = page.bounds(for: .cropBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let ratio = bounds.height / bounds.width
        let size = CGSize(width: targetWidth, height: min(targetWidth * ratio, 4_000))
        return page.thumbnail(of: size, for: .cropBox)
    }

    private func detectBarcodes(in image: CGImage) -> [DetectedBarcode] {
        if let visionBarcodes = try? detectBarcodesWithVision(in: image), !visionBarcodes.isEmpty {
            return visionBarcodes
        }
        return detectQRCodesWithCoreImage(in: image).map { DetectedBarcode(format: .qr, payload: $0) }
    }

    private func detectBarcodesWithVision(in image: CGImage) throws -> [DetectedBarcode] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .code128, .pdf417, .aztec]
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let format = barcodeFormat(for: observation.symbology),
                  let payload = observation.payloadStringValue.flatMap(payloadBytes(for:)) ?? observation.payloadData else {
                return nil
            }
            return DetectedBarcode(format: format, payload: payload)
        }
    }

    private func barcodeFormat(for symbology: VNBarcodeSymbology) -> BarcodeFormat? {
        switch symbology {
        case .qr: .qr
        case .code128: .code128
        case .pdf417: .pdf417
        case .aztec: .aztec
        default: nil
        }
    }

    private func detectQRCodesWithCoreImage(in image: CGImage) -> [Data] {
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let image = CIImage(cgImage: image)
        return detector?.features(in: image).compactMap { feature in
            guard let qrFeature = feature as? CIQRCodeFeature else { return nil }
            return qrFeature.messageString.flatMap(payloadBytes(for:))
        } ?? []
    }

    private func payloadBytes(for value: String) -> Data? {
        value.data(using: .isoLatin1) ?? value.data(using: .utf8)
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
        guard let value = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) || [9, 10, 13].contains($0.value) }) else {
            return nil
        }
        return String(value.prefix(240))
    }
}
