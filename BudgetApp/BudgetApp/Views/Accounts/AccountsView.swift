import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var accountVM: AccountViewModel
    @EnvironmentObject var txVM: TransactionViewModel
    @State private var showAddSheet = false
    @State private var selectedAccount: Account? = nil
    @State private var accountToDelete: Account? = nil

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
        .alert("Delete Account", isPresented: .init(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let account = accountToDelete {
                    Task { await accountVM.deleteAccount(id: account.id) }
                }
                accountToDelete = nil
            }
            Button("Cancel", role: .cancel) { accountToDelete = nil }
        } message: {
            Text("Delete \"\(accountToDelete?.name ?? "")\"? This will permanently delete all transactions for this account.")
        }
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
                accountToDelete = account
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
    @EnvironmentObject var accountVM: AccountViewModel
    @EnvironmentObject var txVM: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentAccount: Account
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    init(account: Account) {
        _currentAccount = State(initialValue: account)
    }

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
                        Text(currentAccount.formattedBalance)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(currentAccount.isPositive ? Theme.textPrimary : Theme.red)
                        Text("Cleared: \(currentAccount.formattedClearedBalance)")
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
            .navigationTitle(currentAccount.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.green)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button("Edit") { showEditSheet = true }
                        Button("Delete Account", role: .destructive) { showDeleteConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundStyle(Theme.green)
                    }
                }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        await accountVM.deleteAccount(id: currentAccount.id)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Delete \"\(currentAccount.name)\"? This will permanently delete all transactions for this account.")
            }
            .task { await txVM.load(accountId: currentAccount.id) }
            .sheet(isPresented: $showEditSheet) {
                EditAccountSheet(account: currentAccount) { name, type, balance, isSavings in
                    Task {
                        if let updated = await accountVM.updateAccount(
                            id: currentAccount.id,
                            name: name,
                            type: type,
                            startingBalance: balance,
                            isSavingsBucket: isSavings
                        ) {
                            currentAccount = updated
                            await txVM.load(accountId: updated.id)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
            }
        }
    }
}

struct EditAccountSheet: View {
    let account: Account
    var onSave: (String, Account.AccountType, Int, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedType: Account.AccountType
    @State private var balanceCents: Int
    @State private var isSavingsBucket: Bool

    init(account: Account, onSave: @escaping (String, Account.AccountType, Int, Bool) -> Void) {
        self.account = account
        self.onSave = onSave
        _name = State(initialValue: account.name)
        _selectedType = State(initialValue: account.type)
        _balanceCents = State(initialValue: account.startingBalance)
        _isSavingsBucket = State(initialValue: account.isSavingsBucket)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    StyledField(text: $name, placeholder: "Account name", icon: "building.columns")
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Account type")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Account.AccountType.allCases, id: \.self) { type in
                                    typeChip(type: type)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    CurrencyField(cents: $balanceCents, label: "Starting balance", fontSize: 36, isInflow: true)
                        .padding(.horizontal, 16)

                    Toggle(isOn: $isSavingsBucket) {
                        HStack(spacing: 8) {
                            Image(systemName: "leaf.fill").foregroundStyle(Theme.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Savings bucket")
                                    .foregroundStyle(Theme.textPrimary)
                                Text("Excluded from daily spending allowance")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.surfaceHigh)
                    .cornerRadius(10)
                    .tint(Theme.blue)
                    .padding(.horizontal, 16)

                    Spacer()

                    Button(action: {
                        onSave(trimmedName, selectedType, balanceCents, isSavingsBucket)
                        dismiss()
                    }) {
                        Text("Save Changes")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? Theme.green : Theme.textTertiary)
                            .cornerRadius(14)
                    }
                    .disabled(!isValid)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func typeChip(type: Account.AccountType) -> some View {
        let selected = selectedType == type
        return Button(action: { selectedType = type }) {
            HStack(spacing: 6) {
                Image(systemName: type.icon).font(.caption)
                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selected ? .black : Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(selected ? Theme.green : Theme.surfaceHigh)
            .cornerRadius(20)
        }
    }
}
