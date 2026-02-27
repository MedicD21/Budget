import Foundation
import SwiftUI

@MainActor
class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var payees: [Payee] = []
    @Published var categories: [FlatCategory] = []
    @Published var isLoading = false
    @Published var error: String?

    var filterAccountId: String?

    func load(accountId: String? = nil) async {
        isLoading = true
        error = nil
        filterAccountId = accountId
        do {
            async let txs = APIService.shared.fetchTransactions(accountId: accountId)
            async let pays = APIService.shared.fetchPayees()
            async let cats = APIService.shared.fetchCategories()
            (transactions, payees, categories) = try await (txs, pays, cats)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func addTransaction(accountId: String, categoryId: String?, payeeName: String?, amount: Int, date: String, memo: String?, cleared: Bool) async {
        do {
            let tx = try await APIService.shared.createTransaction(
                accountId: accountId, categoryId: categoryId, payeeName: payeeName,
                amount: amount, date: date, memo: memo, cleared: cleared
            )
            transactions.insert(tx, at: 0)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTransaction(id: String) async {
        do {
            try await APIService.shared.deleteTransaction(id: id)
            transactions.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleCleared(transaction: Transaction) async {
        do {
            let updated = try await APIService.shared.updateTransaction(id: transaction.id, cleared: !transaction.cleared)
            if let idx = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[idx] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // Group transactions by date for display
    var groupedTransactions: [(date: String, transactions: [Transaction])] {
        let grouped = Dictionary(grouping: transactions, by: { $0.date })
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, transactions: $0.value) }
    }

    // Maps payee name → most recently used category ID (drives autocomplete)
    var payeeCategoryMap: [String: String] {
        var map: [String: String] = [:]
        for tx in transactions.sorted(by: { $0.date > $1.date }) {
            if let name = tx.payeeName, let catId = tx.categoryId, map[name] == nil {
                map[name] = catId
            }
        }
        return map
    }
}
