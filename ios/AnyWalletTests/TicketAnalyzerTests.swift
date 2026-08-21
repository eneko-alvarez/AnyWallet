import UIKit
import XCTest
@testable import AnyWallet

final class TicketAnalyzerTests: XCTestCase {
    func testAnalyzesGeneratedPDFAndPreservesQRPayload() async throws {
        let payload = Data("TICKET|BUS|ABC123|2026-09-14T08:30:00+02:00".utf8)
        let pdf = try makePDF(qrPayload: payload)
        let url = FileManager.default.temporaryDirectory.appending(path: "anywallet-test-\(UUID().uuidString).pdf")
        try pdf.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await TicketAnalyzer().analyze(url: url)

        XCTAssertEqual(result.pageCount, 1)
        XCTAssertEqual(result.qrCandidates.count, 1)
        XCTAssertEqual(result.qrCandidates.first?.payload, payload)
        XCTAssertEqual(result.fields.origin, "Bilbao")
        XCTAssertEqual(result.fields.destination, "Donostia")
        XCTAssertEqual(result.fields.reference, "ABC123")
    }

    private func makePDF(qrPayload: Data) throws -> Data {
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let qrImage = try XCTUnwrap(QRCodeRenderer.image(for: qrPayload, scale: 12))

        return renderer.pdfData { context in
            context.beginPage()
            let title: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            let body: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.label
            ]
            "Autobuses Norte".draw(at: CGPoint(x: 54, y: 54), withAttributes: title)
            "Origen: Bilbao".draw(at: CGPoint(x: 54, y: 110), withAttributes: body)
            "Destino: Donostia".draw(at: CGPoint(x: 54, y: 140), withAttributes: body)
            "Pasajero: Ane Lopez".draw(at: CGPoint(x: 54, y: 170), withAttributes: body)
            "Referencia: ABC123".draw(at: CGPoint(x: 54, y: 200), withAttributes: body)
            qrImage.draw(in: CGRect(x: 170, y: 390, width: 255, height: 255))
        }
    }
}
