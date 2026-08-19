import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }
    var displayName: String { self == .english ? "English" : "Türkçe" }

    func text(_ english: String, _ turkish: String) -> String {
        self == .english ? english : turkish
    }
}
