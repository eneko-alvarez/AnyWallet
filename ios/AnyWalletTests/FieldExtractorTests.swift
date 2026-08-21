import XCTest
@testable import AnyWallet

final class FieldExtractorTests: XCTestCase {
    func testExtractsEditableFields() {
        let fields = FieldExtractor.extract(
            filename: "billete-bus.pdf",
            text: """
            Autobuses Norte
            Origen: Bilbao
            Destino: Donostia
            Pasajero: Ane Lopez
            Referencia: ABC123
            """
        )

        XCTAssertEqual(fields.title, "Autobuses Norte")
        XCTAssertEqual(fields.origin, "Bilbao")
        XCTAssertEqual(fields.destination, "Donostia")
        XCTAssertEqual(fields.passenger, "Ane Lopez")
        XCTAssertEqual(fields.reference, "ABC123")
    }

    func testUsesFilenameWhenDocumentHasNoText() {
        let fields = FieldExtractor.extract(filename: "mi_billete.pdf", text: "")
        XCTAssertEqual(fields.title, "mi billete")
    }

    func testSuggestsMembershipAndExtractsMemberFields() {
        let text = """
        Lidl Plus
        Titular: Ane Lopez
        Número de socio: 204938102
        """
        let fields = FieldExtractor.extract(filename: "lidl-plus.png", text: text)

        XCTAssertEqual(fields.memberName, "Ane Lopez")
        XCTAssertEqual(fields.memberNumber, "204938102")
        XCTAssertEqual(
            FieldExtractor.suggestedPassKind(filename: "lidl-plus.png", text: text, fields: fields),
            .membership
        )
    }

    func testDraftEncodesMissingDateAsNull() throws {
        let draft = PassDraft(
            passKind: .membership,
            title: "Billete",
            issuer: "",
            origin: "",
            destination: "",
            passenger: "",
            reference: "",
            memberName: "",
            memberNumber: "",
            relevantDate: nil,
            barcodeFormat: .qr,
            barcodePayloadBase64: Data("QR".utf8).base64EncodedString(),
            backgroundColor: "rgb(15, 118, 110)"
        )
        let data = try JSONEncoder().encode(draft)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(json["relevantDate"] is NSNull)
    }
}
