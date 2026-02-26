import Foundation
import SwiftUI

@MainActor
class AccountViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var error: String?

    var totalBalance: Int {
        accounts.filter { !$0.isSavingsBucket }.reduce(0) { $0 + $1.computedBalance }
    }

    var savingsBalance: Int {
        accounts.filter { $0.isSavingsBucket }.reduce(0) { $0 + $1.computedBalance }
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            accounts = try await APIService.shared.fetchAccounts()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func addAccount(name: String, type: Account.AccountType, startingBalance: Int, isSavingsBucket: Bool) async {
        do {
            let account = try await APIService.shared.createAccount(
                name: name, type: type, startingBalance: startingBalance, isSavingsBucket: isSavingsBucket
            )
            accounts.append(account)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteAccount(id: String) async {
        do {
            try await APIService.shared.deleteAccount(id: id)
            accounts.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateAccount(id: String, name: String, type: Account.AccountType, startingBalance: Int, isSavingsBucket: Bool) async -> Account? {
        do {
            let updated = try await APIService.shared.updateAccount(
                id: id,
                name: name,
                type: type,
                startingBalance: startingBalance,
                isSavingsBucket: isSavingsBucket
            )
            if let idx = accounts.firstIndex(where: { $0.id == id }) {
                accounts[idx] = updated
            } else {
                accounts.append(updated)
            }
            return updated
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}
