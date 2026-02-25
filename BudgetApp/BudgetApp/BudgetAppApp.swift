import SwiftUI

@main
struct BudgetAppApp: App {
    @StateObject private var budgetVM = BudgetViewModel()
    @StateObject private var txVM = TransactionViewModel()
    @StateObject private var accountVM = AccountViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(budgetVM)
                .environmentObject(txVM)
                .environmentObject(accountVM)
                .preferredColorScheme(.dark)
        }
    }
}
