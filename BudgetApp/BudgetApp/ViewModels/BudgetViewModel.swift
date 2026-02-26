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
        do {
            try await APIService.shared.allocate(year: selectedYear, month: selectedMonth, categoryId: categoryId, amount: amount)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func renameCategory(id: String, name: String) async {
        do {
            try await APIService.shared.renameCategory(id: id, name: name)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCategory(id: String) async {
        do {
            try await APIService.shared.deleteCategory(id: id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
