import SwiftUI

struct AddTransactionSheet: View {
    var accounts: [Account]
    var categories: [FlatCategory]
    var payees: [Payee]
    var payeeCategoryMap: [String: String] = [:]
    var onAdd: (String, String?, String?, Int, String, String?, Bool, Bool) -> Void
    // (accountId, categoryId, payeeName, amount, date, memo, cleared, isInflow)

    @Environment(\.dismiss) private var dismiss

    @State private var selectedAccountId: String = ""
    @State private var selectedCategoryId: String? = nil
    @State private var payeeName: String = ""
    @State private var cents: Int = 0
    @State private var isInflow: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var memo: String = ""
    @State private var cleared: Bool = true
    @State private var showCategoryPicker = false
    @FocusState private var payeeFocused: Bool

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    private var isValid: Bool {
        !selectedAccountId.isEmpty && cents > 0
    }

    private var selectedCategoryName: String {
        categories.first(where: { $0.id == selectedCategoryId })?.name ?? "Select category"
    }

    // Show all payees when focused & empty, filter when typing, hide on exact match
    private var payeeSuggestions: [Payee] {
        guard payeeFocused else { return [] }
        if payeeName.isEmpty {
            return Array(payees.prefix(6))
        }
        let matches = payees.filter { $0.name.localizedCaseInsensitiveContains(payeeName) }
        if matches.count == 1 && matches[0].name.caseInsensitiveCompare(payeeName) == .orderedSame {
            return []
        }
        return Array(matches.prefix(6))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Inflow/Outflow toggle
                        Picker("Type", selection: $isInflow) {
                            Text("Spending").tag(false)
                            Text("Income").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Amount
                        CurrencyField(cents: $cents, label: "Amount", fontSize: 44, isInflow: isInflow)
                            .padding(.horizontal, 16)

                        // Account picker
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Account")
                            if accounts.isEmpty {
                                Text("No accounts — add one in the Accounts tab")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                                    .padding(.horizontal, 16)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(accounts) { account in
                                            accountChip(account: account, isSelected: selectedAccountId == account.id)
                                                .onTapGesture { selectedAccountId = account.id }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Payee with focus-driven autocomplete
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Payee")

                            HStack(spacing: 10) {
                                Image(systemName: "person")
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 20)
                                TextField("Who paid or was paid?", text: $payeeName)
                                    .foregroundStyle(Theme.textPrimary)
                                    .autocorrectionDisabled()
                                    .focused($payeeFocused)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Theme.surfaceHigh)
                            .cornerRadius(10)
                            .padding(.horizontal, 16)

                            // Suggestion dropdown — shows on focus
                            if !payeeSuggestions.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(payeeSuggestions.enumerated()), id: \.element.id) { idx, payee in
                                        Button(action: { selectPayee(payee) }) {
                                            HStack {
                                                Text(payee.name)
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(Theme.textPrimary)
                                                Spacer()
                                                if payeeCategoryMap[payee.name] != nil {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "tag.fill")
                                                            .font(.caption2)
                                                        Text("auto-category")
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(Theme.green.opacity(0.8))
                                                }
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                        }
                                        if idx < payeeSuggestions.count - 1 {
                                            Divider()
                                                .background(Theme.background)
                                                .padding(.leading, 14)
                                        }
                                    }
                                }
                                .background(Theme.surfaceHigh)
                                .cornerRadius(10)
                                .padding(.horizontal, 16)
                            }
                        }

                        // Category
                        if !isInflow {
                            VStack(alignment: .leading, spacing: 6) {
                                fieldLabel("Category")
                                Button(action: { showCategoryPicker = true }) {
                                    HStack {
                                        Image(systemName: "tag")
                                            .foregroundStyle(Theme.textSecondary)
                                            .frame(width: 20)
                                        Text(selectedCategoryName)
                                            .foregroundStyle(selectedCategoryId != nil ? Theme.textPrimary : Theme.textTertiary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Theme.surfaceHigh)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Date
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Date")
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(Theme.green)
                                .padding(.horizontal, 16)
                        }

                        // Memo
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Memo (optional)")
                            StyledField(text: $memo, placeholder: "Note…", icon: "note.text")
                                .padding(.horizontal, 16)
                        }

                        // Cleared toggle
                        HStack {
                            Toggle(isOn: $cleared) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(cleared ? Theme.green : Theme.textTertiary)
                                    Text("Mark as cleared")
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                            .tint(Theme.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.surfaceHigh)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 8)

                        // Submit
                        Button(action: submit) {
                            Text("Save Transaction")
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
                }
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(categories: categories, selectedId: $selectedCategoryId)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Theme.background)
            }
            .onAppear {
                if let first = accounts.first { selectedAccountId = first.id }
            }
        }
    }

    private func selectPayee(_ payee: Payee) {
        payeeName = payee.name
        payeeFocused = false   // dismiss keyboard + collapse suggestions
        if !isInflow, let catId = payeeCategoryMap[payee.name] {
            selectedCategoryId = catId
        }
    }

    private func submit() {
        let finalAmount = isInflow ? cents : -cents
        onAdd(selectedAccountId, isInflow ? nil : selectedCategoryId, payeeName.isEmpty ? nil : payeeName,
              finalAmount, dateString, memo.isEmpty ? nil : memo, cleared, isInflow)
        dismiss()
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 16)
    }

    private func accountChip(account: Account, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: account.type.icon)
                .font(.caption)
            Text(account.name)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(isSelected ? .black : Theme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Theme.green : Theme.surfaceHigh)
        .cornerRadius(20)
    }
}

struct CategoryPickerSheet: View {
    var categories: [FlatCategory]
    @Binding var selectedId: String?
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [FlatCategory] {
        search.isEmpty ? categories : categories.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.groupName.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(String, [FlatCategory])] {
        let dict = Dictionary(grouping: filtered, by: { $0.groupName })
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                List {
                    ForEach(grouped, id: \.0) { groupName, cats in
                        Section(header: Text(groupName).foregroundStyle(Theme.textSecondary)) {
                            ForEach(cats) { cat in
                                Button(action: { selectedId = cat.id; dismiss() }) {
                                    HStack {
                                        Text(cat.name).foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        if selectedId == cat.id {
                                            Image(systemName: "checkmark").foregroundStyle(Theme.green)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
                .tint(Theme.green)
            }
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
