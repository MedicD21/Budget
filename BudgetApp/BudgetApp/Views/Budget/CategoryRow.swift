import SwiftUI

struct CategoryRow: View {
    var category: BudgetCategory
    var onTap: () -> Void
    var onDelete: () -> Void

    private var availableColor: Color {
        switch category.availableColor {
        case .green:   return Theme.green
        case .red:     return Theme.red
        case .neutral: return Theme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Category name
            Button(action: onTap) {
                HStack(spacing: 10) {
                    if category.isSavings {
                        Image(systemName: "leaf.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.blue)
                    }
                    Text(category.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Assigned column — tappable number field feel
            Button(action: onTap) {
                Text(formatCurrency(category.allocated))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 84, alignment: .trailing)
            }

            // Activity column — read only
            Text(category.activity == 0 ? "—" : formatCurrency(abs(category.activity)))
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 84, alignment: .trailing)

            // Available pill
            Text(formatCurrency(abs(category.available)))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(category.available == 0 ? Theme.textTertiary : availableColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    availableColor
                        .opacity(category.available == 0 ? 0 : 0.15)
                        .cornerRadius(6)
                )
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Theme.surface)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
