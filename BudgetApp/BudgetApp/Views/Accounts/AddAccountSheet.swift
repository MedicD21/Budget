import SwiftUI

struct AddAccountSheet: View {
    var onAdd: (String, Account.AccountType, Int, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedType: Account.AccountType = .checking
    @State private var balanceCents: Int = 0
    @State private var isSavingsBucket = false

    private var isValid: Bool { !name.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    StyledField(text: $name, placeholder: "Account name (e.g. Chase Checking)", icon: "building.columns")
                        .padding(.horizontal, 16)

                    // Type picker
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

                    // Starting balance
                    CurrencyField(cents: $balanceCents, label: "Starting balance", fontSize: 36, isInflow: true)
                        .padding(.horizontal, 16)

                    // Savings bucket toggle
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

                    Button(action: { onAdd(name, selectedType, balanceCents, isSavingsBucket); dismiss() }) {
                        Text("Add Account")
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
            .navigationTitle("Add Account")
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
