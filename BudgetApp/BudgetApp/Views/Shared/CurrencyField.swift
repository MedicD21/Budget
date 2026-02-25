import SwiftUI

/// A large, tap-friendly currency input that fills digits from right (cent-based entry).
/// Example: type "1" → $0.01, "5" → $0.15, "0" → $1.50
struct CurrencyField: View {
    @Binding var cents: Int
    var label: String = "Amount"
    var fontSize: CGFloat = 40
    var isInflow: Bool = false   // changes sign color

    @FocusState private var focused: Bool
    @State private var rawInput: String = ""

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            ZStack {
                // Invisible text field captures keyboard input
                TextField("", text: $rawInput)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .onChange(of: rawInput) { _, newVal in
                        let digits = newVal.filter { $0.isNumber }
                        let clamped = String(digits.suffix(9)) // max $9,999,999.99
                        rawInput = clamped
                        cents = Int(clamped) ?? 0
                    }
                    .opacity(0)
                    .frame(width: 1, height: 1)

                // Styled display
                HStack(spacing: 2) {
                    Text(isInflow ? "+" : "-")
                        .font(.system(size: fontSize * 0.6, weight: .medium, design: .rounded))
                        .foregroundStyle(isInflow ? Theme.green : Theme.red)
                    Text(formatCurrency(cents))
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Theme.surfaceHigh)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focused ? Theme.green : Color.clear, lineWidth: 2)
                )
                .onTapGesture { focused = true }
            }
        }
        .onAppear {
            rawInput = cents > 0 ? "\(cents)" : ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focused = true
            }
        }
    }
}

/// Simpler styled text field for non-currency inputs
struct StyledField: View {
    @Binding var text: String
    var placeholder: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 20)
            }
            TextField(placeholder, text: $text)
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surfaceHigh)
        .cornerRadius(10)
    }
}
