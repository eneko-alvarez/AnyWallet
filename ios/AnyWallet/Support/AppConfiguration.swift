import Foundation

enum AppConfiguration {
    static var apiBaseURL: URL {
        if let override = UserDefaults.standard.string(forKey: "APIBaseURLOverride"),
           let url = URL(string: override) {
            return url
        }
        guard let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              let url = URL(string: value) else {
            preconditionFailure("APIBaseURL is missing from Info.plist")
        }
        return url
    }
}
