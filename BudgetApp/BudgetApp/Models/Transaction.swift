import Foundation

struct Transaction: Identifiable, Codable, Hashable {
    let id: String
    var accountId: String
    var accountName: String?
    var categoryId: String?
    var categoryName: String?
    var categoryGroupName: String?
    var payeeId: String?
    var payeeName: String?
    var amount: Int          // cents; positive = inflow, negative = outflow
    var date: String         // "YYYY-MM-DD"
    var memo: String?
    var cleared: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, date, memo, cleared
        case accountId = "account_id"
        case accountName = "account_name"
        case categoryId = "category_id"
        case categoryName = "category_name"
        case categoryGroupName = "category_group_name"
        case payeeId = "payee_id"
        case payeeName = "payee_name"
        case createdAt = "created_at"
    }

    var isInflow: Bool { amount >= 0 }

    var formattedAmount: String {
        let formatted = formatCurrency(abs(amount))
        return isInflow ? "+\(formatted)" : "-\(formatted)"
    }

    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var displayDate: String {
        guard let d = parsedDate else { return date }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: d)
    }
}

struct Payee: Identifiable, Codable, Hashable {
    let id: String
    var name: String
}
