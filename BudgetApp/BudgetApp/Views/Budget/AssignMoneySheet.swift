import SwiftUI

struct AssignMoneySheet: View {
    var category: BudgetCategory
    var readyToAssign: Int
    var onAssign: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var cents: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Category info
                    VStack(spacing: 6) {
                        Text(category.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)

                        HStack(spacing: 16) {
                            statPill(label: "Assigned", value: formatCurrency(category.allocated), color: Theme.textSecondary)
                            statPill(label: "Activity", value: formatCurrency(abs(category.activity)), color: Theme.textSecondary)
                            statPill(label: "Available", value: formatCurrency(abs(category.available)),
                                     color: category.available >= 0 ? Theme.green : Theme.red)
                        }
                    }
                    .padding(.top, 8)

                    // Ready to assign reminder
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Theme.textSecondary)
                        Text("**\(formatCurrency(readyToAssign))** ready to assign")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.surfaceHigh)
                    .cornerRadius(10)

                    // Currency input
                    CurrencyField(cents: $cents, label: "Assign to this category", fontSize: 44)
                        .padding(.horizontal, 16)

                    // Quick-assign shortcuts
                    HStack(spacing: 10) {
                        quickButton(label: "Clear", amount: 0)
                        quickButton(label: "Keep current", amount: category.allocated)
                        quickButton(label: "Cover activity", amount: max(0, -category.activity))
                        quickButton(label: "All available", amount: max(0, readyToAssign + category.allocated))
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Confirm button
                    Button(action: { onAssign(cents); dismiss() }) {
                        Text("Assign \(formatCurrency(cents))")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.green)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear { cents = category.allocated }
    }

    private func quickButton(label: String, amount: Int) -> some View {
        Button(action: { cents = amount }) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.surfaceHigh)
                .cornerRadius(8)
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.surfaceHigh)
        .cornerRadius(8)
    }
}
