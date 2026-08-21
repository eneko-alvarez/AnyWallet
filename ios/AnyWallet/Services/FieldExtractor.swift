import Foundation

enum FieldExtractor {
    static func extract(filename: String, text: String) -> TicketFields {
        let normalized = String(text.prefix(100_000))
        return TicketFields(
            title: title(filename: filename, text: normalized),
            issuer: value(in: normalized, labels: ["operador", "compañía", "compania", "empresa", "comercio", "programa", "supermercado", "carrier", "operator", "retailer"]),
            origin: value(in: normalized, labels: ["origen", "salida", "desde", "from", "departure"]),
            destination: value(in: normalized, labels: ["destino", "llegada", "hasta", "to", "arrival"]),
            passenger: value(in: normalized, labels: ["pasajero", "viajero", "nombre", "passenger", "traveller"]),
            reference: value(in: normalized, labels: ["localizador", "reserva", "referencia", "booking", "reference", "pnr"]),
            memberName: value(in: normalized, labels: ["titular", "nombre del socio", "member name", "cardholder"]),
            memberNumber: value(in: normalized, labels: ["número de socio", "numero de socio", "nº de socio", "id de socio", "número de cliente", "numero de cliente", "member id", "member number", "customer number", "card number"]),
            relevantDate: firstDate(in: normalized)
        )
    }

    static func suggestedPassKind(filename: String, text: String, fields: TicketFields) -> PassKind {
        let searchable = "\(filename)\n\(text)".lowercased()
        let membershipTerms = [
            "membresía", "membresia", "socio", "fidelización", "fidelizacion",
            "tarjeta cliente", "club card", "loyalty", "membership", "member id",
            "customer card", "lidl plus"
        ]
        if !fields.memberNumber.isEmpty || membershipTerms.contains(where: searchable.contains) {
            return .membership
        }

        let travelTerms = [
            "origen", "destino", "departure", "arrival", "boarding pass", "pasajero",
            "viajero", "vuelo", "flight", "autobús", "autobus", "tren", "train"
        ]
        if !fields.origin.isEmpty || !fields.destination.isEmpty || travelTerms.contains(where: searchable.contains) {
            return .travel
        }
        return .travel
    }

    private static func title(filename: String, text: String) -> String {
        let ignored = Set(["billete", "ticket", "boarding pass", "reserva", "booking"])
        if let line = text.components(separatedBy: .newlines)
            .map(clean)
            .first(where: { (3...55).contains($0.count) && !ignored.contains($0.lowercased()) }) {
            return line
        }
        let fallback = (filename as NSString).deletingPathExtension
            .replacingOccurrences(of: "[_-]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "Mi billete" : fallback
    }

    private static func value(in text: String, labels: [String]) -> String {
        let labelsPattern = labels.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let pattern = "(?im)^\\s*(?:\(labelsPattern))\\s*[:#-]?\\s*([^\\r\\n]{2,80})"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return ""
        }
        return clean(String(text[range]))
    }

    private static func firstDate(in text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.date
    }

    private static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
