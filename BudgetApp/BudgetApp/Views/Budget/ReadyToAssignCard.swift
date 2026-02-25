import SwiftUI

struct ReadyToAssignCard: View {
    var readyToAssign: Int
    var isOverAssigned: Bool

    var cardColor: Color { isOverAssigned ? Theme.red : Theme.green }
    var label: String { isOverAssigned ? "Over-Assigned" : "Ready to Assign" }

    var body: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(cardColor.opacity(0.85))
                .tracking(1.2)

            Text(formatCurrency(abs(readyToAssign)))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(cardColor)

            if isOverAssigned {
                Label("You've over-budgeted", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(cardColor.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(cardColor.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardColor.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}
