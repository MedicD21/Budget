import Foundation

struct Account: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var type: AccountType
    var startingBalance: Int      // cents
    var isSavingsBucket: Bool
    var sortOrder: Int
    var computedBalance: Int      // cents, from API
    var clearedBalance: Int       // cents, cleared transactions only
    let createdAt: String?

    enum AccountType: String, Codable, CaseIterable {
        case checking, savings, credit_card, cash

        var displayName: String {
            switch self {
            case .checking:    return "Checking"
            case .savings:     return "Savings"
            case .credit_card: return "Credit Card"
            case .cash:        return "Cash"
            }
        }

        var icon: String {
            switch self {
            case .checking:    return "banknote"
            case .savings:     return "building.columns"
            case .credit_card: return "creditcard"
            case .cash:        return "dollarsign.circle"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case startingBalance = "starting_balance"
        case isSavingsBucket = "is_savings_bucket"
        case sortOrder = "sort_order"
        case computedBalance = "computed_balance"
        case clearedBalance = "cleared_balance"
        case createdAt = "created_at"
    }
}

extension Account {
    var formattedBalance: String {
        formatCurrency(computedBalance)
    }

    var formattedClearedBalance: String {
        formatCurrency(clearedBalance)
    }

    var isPositive: Bool { computedBalance >= 0 }
}
