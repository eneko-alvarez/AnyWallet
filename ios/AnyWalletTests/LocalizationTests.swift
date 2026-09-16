import XCTest
@testable import AnyWallet

final class LocalizationTests: XCTestCase {
    func testOnlyPrimarySpanishSelectsSpanish() {
        for language in ["es", "es-ES", "es-MX", "es-419"] {
            XCTAssertEqual(L10n.language(for: [language, "en"]), "es")
        }
        for language in ["en", "en-GB", "fr-FR", "ca-ES", "de-DE", "ja", "ar"] {
            XCTAssertEqual(L10n.language(for: [language, "es"]), "en")
        }
        XCTAssertEqual(L10n.language(for: []), "en")
    }

    func testBundledTranslationsHaveMatchingKeysAndFormats() throws {
        func strings(_ language: String) throws -> [String: String] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language))
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        }
        let spanish = try strings("es")
        let english = try strings("en")
        XCTAssertEqual(Set(spanish.keys), Set(english.keys))
        let pattern = try NSRegularExpression(pattern: "%[@d]")
        for (key, value) in spanish {
            let translation = try XCTUnwrap(english[key])
            XCTAssertFalse(translation.isEmpty)
            func placeholders(_ text: String) -> [String] {
                pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range) }
            }
            XCTAssertEqual(placeholders(value), placeholders(translation), key)
        }
        XCTAssertEqual(L10n.text("Crear pase", language: "en"), "Create pass")
        XCTAssertEqual(L10n.text("Crear pase", language: "es"), "Crear pase")
    }
}
