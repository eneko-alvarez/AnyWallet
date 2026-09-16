import SwiftUI

enum AppTheme {
    static let ink = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let muted = Color(red: 0.392, green: 0.455, blue: 0.545)
    static let canvas = Color(red: 0.953, green: 0.961, blue: 0.969)
    static let surface = Color.white
    static let line = Color(red: 0.847, green: 0.871, blue: 0.906)
    static let accent = Color(red: 0.059, green: 0.463, blue: 0.431)
    static let danger = Color(red: 0.706, green: 0.137, blue: 0.094)
}

struct PassColor: Identifiable, Equatable {
    let id: String
    let name: String
    let cssValue: String
    let color: Color

    static func == (lhs: PassColor, rhs: PassColor) -> Bool {
        lhs.id == rhs.id
    }

    static let choices = [
        PassColor(id: "green", name: L10n.text("Verde"), cssValue: "rgb(15, 118, 110)", color: .init(red: 0.059, green: 0.463, blue: 0.431)),
        PassColor(id: "blue", name: L10n.text("Azul"), cssValue: "rgb(29, 78, 216)", color: .init(red: 0.114, green: 0.306, blue: 0.847)),
        PassColor(id: "red", name: L10n.text("Rojo"), cssValue: "rgb(185, 28, 28)", color: .init(red: 0.725, green: 0.110, blue: 0.110)),
        PassColor(id: "black", name: L10n.text("Negro"), cssValue: "rgb(24, 24, 27)", color: .init(red: 0.094, green: 0.094, blue: 0.106)),
        PassColor(id: "violet", name: L10n.text("Violeta"), cssValue: "rgb(109, 40, 217)", color: .init(red: 0.427, green: 0.157, blue: 0.851))
    ]
}
