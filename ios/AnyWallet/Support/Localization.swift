import Foundation

/// Use only the first device language: all Spanish variants use Spanish;
/// every other language uses English, even when Spanish is a secondary preference.
enum L10n {
    static func language(for preferredLanguages: [String]) -> String {
        guard let first = preferredLanguages.first else { return "en" }
        return Locale(identifier: first).language.languageCode?.identifier == "es" ? "es" : "en"
    }

    static var language: String { language(for: Locale.preferredLanguages) }
    static var locale: Locale { Locale(identifier: language) }

    static func text(_ key: String, language: String = language) -> String {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
}
