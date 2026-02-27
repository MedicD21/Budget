import Foundation
import SwiftUI

@MainActor
class BudgetViewModel: ObservableObject {
    @Published var budget: BudgetMonth?
    @Published var isLoading = false
    @Published var error: String?

    @Published var selectedYear: Int
    @Published var selectedMonth: Int

    init() {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        selectedYear = now.year ?? 2026
        selectedMonth = now.month ?? 1
    }

    private var currentCategories: [BudgetCategory] {
        budget?.groups.flatMap(\.categories) ?? []
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            budget = try await APIService.shared.fetchBudget(year: selectedYear, month: selectedMonth)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func goToPreviousMonth() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
        Task { await load() }
    }

    func goToNextMonth() {
        if selectedMonth == 12 {
            selectedMonth = 1
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
        Task { await load() }
    }

    func assign(categoryId: String, amount: Int) async {
        await performMutation {
            try await APIService.shared.allocate(year: selectedYear, month: selectedMonth, categoryId: categoryId, amount: amount)
        }
    }

    func createCategory(groupId: String?, newGroupName: String?, categoryName: String, isSavings: Bool, dueDay: Int?, recurrence: String?, targetAmount: Int?, notes: String?) async {
        let trimmedCategoryName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCategoryName.isEmpty else {
            error = "Category name is required"
            return
        }

        await performMutation {
            let resolvedGroupId: String
            if let groupId, !groupId.isEmpty {
                resolvedGroupId = groupId
            } else {
                let trimmedGroupName = newGroupName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !trimmedGroupName.isEmpty else {
                    throw APIError.serverError(400, "Choose a group or enter a new group name")
                }
                let sortOrder = (budget?.groups.map(\.sortOrder).max() ?? -1) + 1
                let group = try await APIService.shared.createCategoryGroup(name: trimmedGroupName, sortOrder: sortOrder)
                resolvedGroupId = group.id
            }

            _ = try await APIService.shared.createCategory(
                groupId: resolvedGroupId,
                name: trimmedCategoryName,
                isSavings: isSavings,
                dueDay: dueDay,
                recurrence: recurrence,
                targetAmount: targetAmount,
                notes: notes
            )
        }
    }

    func updateCategory(id: String, name: String, groupId: String, isSavings: Bool, dueDay: Int?, recurrence: String?, targetAmount: Int?, notes: String?) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            error = "Category name is required"
            return
        }

        await performMutation {
            try await APIService.shared.updateCategory(
                id: id,
                name: trimmedName,
                groupId: groupId,
                isSavings: isSavings,
                dueDay: dueDay,
                recurrence: recurrence,
                targetAmount: targetAmount,
                notes: notes
            )
        }
    }

    func deleteCategory(id: String) async {
        await performMutation {
            try await APIService.shared.deleteCategory(id: id)
        }
    }

    func createGroup(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Group name is required"
            return
        }

        await performMutation {
            let sortOrder = (budget?.groups.map(\.sortOrder).max() ?? -1) + 1
            _ = try await APIService.shared.createCategoryGroup(name: trimmed, sortOrder: sortOrder)
        }
    }

    func renameGroup(id: String, name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Group name is required"
            return
        }

        await performMutation {
            _ = try await APIService.shared.updateCategoryGroup(id: id, name: trimmed)
        }
    }

    func deleteGroup(id: String) async {
        await performMutation {
            try await APIService.shared.deleteCategoryGroup(id: id)
        }
    }

    func coverOverspent() async {
        let assignments = currentCategories.compactMap { category -> (categoryId: String, allocated: Int)? in
            guard category.available < 0 else { return nil }
            return (categoryId: category.id, allocated: category.allocated + abs(category.available))
        }
        guard !assignments.isEmpty else { return }

        await performMutation {
            try await APIService.shared.bulkAllocate(year: selectedYear, month: selectedMonth, assignments: assignments)
        }
    }

    func fundTargets() async {
        let assignments = currentCategories.compactMap { category -> (categoryId: String, allocated: Int)? in
            guard let targetAmount = category.targetAmount, targetAmount > category.allocated else { return nil }
            return (categoryId: category.id, allocated: targetAmount)
        }
        guard !assignments.isEmpty else { return }

        await performMutation {
            try await APIService.shared.bulkAllocate(year: selectedYear, month: selectedMonth, assignments: assignments)
        }
    }

    func copyPreviousMonthPlan() async {
        guard budget != nil else { return }
        let (year, month) = previousMonth(from: selectedYear, month: selectedMonth)

        do {
            let previousBudget = try await APIService.shared.fetchBudget(year: year, month: month)
            let previousMap = Dictionary(uniqueKeysWithValues:
                previousBudget.groups
                    .flatMap(\.categories)
                    .map { ($0.id, $0.allocated) }
            )

            let assignments = currentCategories.compactMap { category -> (categoryId: String, allocated: Int)? in
                guard let previousAllocated = previousMap[category.id], previousAllocated != category.allocated else { return nil }
                return (categoryId: category.id, allocated: previousAllocated)
            }

            guard !assignments.isEmpty else { return }

            try await APIService.shared.bulkAllocate(year: selectedYear, month: selectedMonth, assignments: assignments)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func resetCurrentMonthPlan() async {
        await performMutation {
            try await APIService.shared.resetMonthAllocations(year: selectedYear, month: selectedMonth)
        }
    }

    private func previousMonth(from year: Int, month: Int) -> (year: Int, month: Int) {
        if month == 1 {
            return (year - 1, 12)
        }
        return (year, month - 1)
    }

    private func performMutation(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
