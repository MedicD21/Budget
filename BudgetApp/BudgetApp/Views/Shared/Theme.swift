import SwiftUI

enum Theme {
    // Backgrounds
    static let background   = Color(red: 0.10, green: 0.12, blue: 0.18)  // #1A1F2E
    static let surface      = Color(red: 0.14, green: 0.16, blue: 0.22)  // #242938
    static let surfaceHigh  = Color(red: 0.18, green: 0.21, blue: 0.28)  // #2D3547

    // Accents
    static let green        = Color(red: 0.00, green: 0.78, blue: 0.59)  // #00C896
    static let red          = Color(red: 1.00, green: 0.28, blue: 0.34)  // #FF4757
    static let yellow       = Color(red: 1.00, green: 0.65, blue: 0.15)  // #FFA726
    static let blue         = Color(red: 0.30, green: 0.60, blue: 1.00)  // #4D99FF

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color(white: 0.60)
    static let textTertiary  = Color(white: 0.40)
}

// Reusable card background modifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .cornerRadius(12)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
