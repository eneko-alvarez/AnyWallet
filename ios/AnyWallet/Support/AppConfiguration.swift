import Foundation

enum AppConfiguration {
    static var apiBaseURL: URL {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              let url = URL(string: value),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              url.host != nil else {
            preconditionFailure("APIBaseURL is missing from Info.plist")
        }
        return url
    }

    static var appAttestRequired: Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AppAttestRequired") as? String else {
            return false
        }
        return value.caseInsensitiveCompare("YES") == .orderedSame || value == "1" || value.lowercased() == "true"
    }

    static var interstitialAdUnitID: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "InterstitialAdUnitID") as? String,
              value.hasPrefix("ca-app-pub-") else {
            preconditionFailure("InterstitialAdUnitID is missing from Info.plist")
        }
        return value
    }
}
