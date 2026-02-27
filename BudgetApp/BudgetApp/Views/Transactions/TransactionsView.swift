import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var accountVM: AccountViewModel
    @State private var showAddSheet = false
    @State private var selectedAccountFilter: String? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Account filter chips
                if !accountVM.accounts.isEmpty {
                    accountFilterBar
                }

                if txVM.isLoading && txVM.transactions.isEmpty {
                    Spacer()
                    ProgressView().tint(Theme.green)
                    Spacer()
                } else if txVM.transactions.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .foregroundStyle(Theme.green)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionSheet(
                accounts: accountVM.accounts,
                categories: txVM.categories,
                payees: txVM.payees,
                payeeCategoryMap: txVM.payeeCategoryMap,
                onAdd: { accountId, categoryId, payeeName, amount, date, memo, cleared, _ in
                    Task {
                        await txVM.addTransaction(
                            accountId: accountId, categoryId: categoryId, payeeName: payeeName,
                            amount: amount, date: date, memo: memo, cleared: cleared
                        )
                        await accountVM.load()
                    }
                }
            )
            .presentationDetents([.large])
            .presentationBackground(Theme.background)
        }
        .task {
            async let txLoad: Void = txVM.load(accountId: selectedAccountFilter)
            async let acctLoad: Void = accountVM.load()
            _ = await txLoad
            _ = await acctLoad
        }
        .onChange(of: selectedAccountFilter) { _, newVal in
            Task { await txVM.load(accountId: newVal) }
        }
        .alert("Error", isPresented: .init(
            get: { txVM.error != nil },
            set: { if !$0 { txVM.error = nil } }
        )) {
            Button("OK") { txVM.error = nil }
        } message: { Text(txVM.error ?? "") }
    }

    private var accountFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", id: nil)
                ForEach(accountVM.accounts) { account in
                    filterChip(label: account.name, id: account.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.background)
    }

    private func filterChip(label: String, id: String?) -> some View {
        Button(action: { selectedAccountFilter = id }) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selectedAccountFilter == id ? .black : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selectedAccountFilter == id ? Theme.green : Theme.surfaceHigh)
                .cornerRadius(20)
        }
    }

    private var transactionList: some View {
        List {
            ForEach(txVM.groupedTransactions, id: \.date) { group in
                Section(header: sectionHeader(date: group.date)) {
                    ForEach(group.transactions) { tx in
                        TransactionRow(transaction: tx)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await txVM.deleteTransaction(id: tx.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    Task { await txVM.toggleCleared(transaction: tx) }
                                } label: {
                                    Label(tx.cleared ? "Unclear" : "Clear", systemImage: tx.cleared ? "xmark.circle" : "checkmark.circle")
                                }
                                .tint(Theme.blue)
                            }
                            .listRowBackground(Theme.surface)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await txVM.load(accountId: selectedAccountFilter) }
    }

    private func sectionHeader(date: String) -> some View {
        let formatted: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            if let d = f.date(from: date) {
                f.dateStyle = .medium
                f.timeStyle = .none
                return f.string(from: d)
            }
            return date
        }()
        return Text(formatted)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(nil)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textTertiary)
            Text("No transactions yet")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
            Button(action: { showAddSheet = true }) {
                Label("Add a transaction", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.green)
                    .cornerRadius(12)
            }
            Spacer()
        }
    }
}

struct TransactionRow: View {
    var transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Category / type indicator
            Circle()
                .fill(transaction.isInflow ? Theme.green.opacity(0.2) : Theme.surfaceHigh)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: transaction.isInflow ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(transaction.isInflow ? Theme.green : Theme.textSecondary)
                )

            // Payee + category
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.payeeName ?? "No payee")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let cat = transaction.categoryName {
                        Text(cat)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if let acct = transaction.accountName {
                        Text("·")
                            .foregroundStyle(Theme.textTertiary)
                        Text(acct)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            Spacer()

            // Amount + cleared
            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedAmount)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(transaction.isInflow ? Theme.green : Theme.textPrimary)
                if transaction.cleared {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.green.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
