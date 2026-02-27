import SwiftUI

struct CategoryGroupSection: View {
    var group: CategoryGroup
    @Binding var collapsed: Bool
    var onTapCategory: (BudgetCategory) -> Void
    var onEditCategory: (BudgetCategory) -> Void
    var onDeleteCategory: (BudgetCategory) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            Button(action: { withAnimation(.spring(response: 0.3)) { collapsed.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 14)

                    Text(group.name.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .tracking(0.8)

                    Spacer()

                    // Group totals
                    if !collapsed {
                        HStack(spacing: 0) {
                            Text(formatCurrency(group.totalAllocated))
                                .frame(width: 84, alignment: .trailing)
                            Text(
                                group.totalActivity == 0
                                    ? "—" : formatCurrency(abs(group.totalActivity))
                            )
                            .frame(width: 84, alignment: .trailing)
                            Text(formatCurrency(abs(group.totalAvailable)))
                                .foregroundStyle(
                                    group.totalAvailable >= 0 ? Theme.green : Theme.red
                                )
                                .frame(width: 90, alignment: .trailing)
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.background)
            }
            .buttonStyle(.plain)

            if !collapsed {
                ForEach(
                    group.categories.sorted(by: { lhs, rhs in
                        switch (lhs.dueDay, rhs.dueDay) {
                        case (let l?, let r?):
                            if l != r { return l < r }
                            return lhs.sortOrder < rhs.sortOrder
                        case (nil, nil):
                            return lhs.sortOrder < rhs.sortOrder
                        case (nil, _):
                            return false  // nil dueDay goes after
                        case (_, nil):
                            return true  // dueDay comes first
                        }
                    })
                ) { category in
                    CategoryRow(
                        category: category,
                        onTap: { onTapCategory(category) },
                        onEdit: { onEditCategory(category) },
                        onDelete: { onDeleteCategory(category) }
                    )
                    Divider()
                        .background(Theme.surfaceHigh)
                        .padding(.leading, 16)
                }
            }
        }
    }
}
