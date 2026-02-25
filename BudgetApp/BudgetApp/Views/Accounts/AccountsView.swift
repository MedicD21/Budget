import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var accountVM: AccountViewModel
    @EnvironmentObject var txVM: TransactionViewModel
    @State private var showAddSheet = false
    @State private var selectedAccount: Account? = nil

    var spendingAccounts: [Account] { accountVM.accounts.filter { !$0.isSavingsBucket } }
    var savingsAccounts: [Account] { accountVM.accounts.filter { $0.isSavingsBucket } }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Net worth summary card
                    summaryCard

                    // Spending accounts
                    if !spendingAccounts.isEmpty {
                        accountSection(title: "SPENDING", accounts: spendingAccounts)
                    }

                    // Savings accounts
                    if !savingsAccounts.isEmpty {
                        accountSection(title: "SAVINGS", accounts: savingsAccounts)
                    }

                    if accountVM.accounts.isEmpty {
                        emptyState
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .refreshable { await accountVM.load() }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus").foregroundStyle(Theme.green)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAccountSheet { name, type, balance, isSavings in
                Task { await accountVM.addAccount(name: name, type: type, startingBalance: balance, isSavingsBucket: isSavings) }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.background)
        }
        .sheet(item: $selectedAccount) { account in
            AccountDetailSheet(account: account)
                .presentationDetents([.large])
                .presentationBackground(Theme.background)
        }
        .task { await accountVM.load() }
        .alert("Error", isPresented: .init(
            get: { accountVM.error != nil },
            set: { if !$0 { accountVM.error = nil } }
        )) {
            Button("OK") { accountVM.error = nil }
        } message: { Text(accountVM.error ?? "") }
    }

    private var summaryCard: some View {
        VStack(spacing: 4) {
            Text("NET WORTH")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1)
            Text(formatCurrency(accountVM.totalBalance + accountVM.savingsBalance))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("Spending")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text(formatCurrency(accountVM.totalBalance))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Rectangle().frame(width: 1, height: 28).foregroundStyle(Theme.surfaceHigh)
                VStack(spacing: 2) {
                    Text("Savings")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text(formatCurrency(accountVM.savingsBalance))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Theme.surface)
        .cornerRadius(16)
    }

    private func accountSection(title: String, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(1)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)

            VStack(spacing: 1) {
                ForEach(accounts) { account in
                    accountRow(account: account)
                }
            }
            .background(Theme.surface)
            .cornerRadius(12)
        }
    }

    private func accountRow(account: Account) -> some View {
        Button(action: { selectedAccount = account }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.surfaceHigh)
                        .frame(width: 40, height: 40)
                    Image(systemName: account.type.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(account.isSavingsBucket ? Theme.blue : Theme.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(account.type.displayName)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(account.formattedBalance)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(account.isPositive ? Theme.textPrimary : Theme.red)
                    Text("cleared \(account.formattedClearedBalance)")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await accountVM.deleteAccount(id: account.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textTertiary)
            Text("No accounts yet")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
            Button(action: { showAddSheet = true }) {
                Label("Add your first account", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.green)
                    .cornerRadius(12)
            }
        }
        .padding(.top, 60)
    }
}

struct AccountDetailSheet: View {
    var account: Account
    @EnvironmentObject var txVM: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Balance header
                    VStack(spacing: 4) {
                        Text("WORKING BALANCE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                            .tracking(1)
                        Text(account.formattedBalance)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(account.isPositive ? Theme.textPrimary : Theme.red)
                        Text("Cleared: \(account.formattedClearedBalance)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Theme.surface)

                    // Transactions for this account
                    if txVM.transactions.isEmpty {
                        Spacer()
                        Text("No transactions for this account")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    } else {
                        List {
                            ForEach(txVM.groupedTransactions, id: \.date) { group in
                                Section(header: Text(group.date).foregroundStyle(Theme.textSecondary).font(.caption)) {
                                    ForEach(group.transactions) { tx in
                                        TransactionRow(transaction: tx)
                                            .listRowBackground(Theme.surface)
                                            .listRowInsets(EdgeInsets())
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(account.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.green)
                }
            }
            .task { await txVM.load(accountId: account.id) }
        }
    }
}
