import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BudgetView()
            }
            .tabItem {
                Label("Budget", systemImage: "chart.bar.fill")
            }
            .tag(0)

            NavigationStack {
                TransactionsView()
            }
            .tabItem {
                Label("Transactions", systemImage: "list.bullet")
            }
            .tag(1)

            NavigationStack {
                AccountsView()
            }
            .tabItem {
                Label("Accounts", systemImage: "creditcard.fill")
            }
            .tag(2)

            NavigationStack {
                AIAssistantView()
            }
            .tabItem {
                Label("Assistant", systemImage: "brain.head.profile")
            }
            .tag(3)
        }
        .tint(Theme.green)
        .background(Theme.background)
        // Dark tab bar styling
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Theme.surface)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithOpaqueBackground()
            navAppearance.backgroundColor = UIColor(Theme.background)
            navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        }
    }
}
