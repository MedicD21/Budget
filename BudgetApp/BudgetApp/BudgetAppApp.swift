import SwiftUI

@main
struct BudgetAppApp: App {
    @StateObject private var budgetVM = BudgetViewModel()
    @StateObject private var txVM = TransactionViewModel()
    @StateObject private var accountVM = AccountViewModel()
    @StateObject private var aiVM = AIViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(budgetVM)
                .environmentObject(txVM)
                .environmentObject(accountVM)
                .environmentObject(aiVM)
                .preferredColorScheme(.dark)
        }
    }
}
