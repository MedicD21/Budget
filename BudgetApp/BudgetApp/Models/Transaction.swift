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

    // Neon returns BIGINT as a JSON string; accept either number or string for `amount`
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self, forKey: .id)
        accountId        = try c.decode(String.self, forKey: .accountId)
        accountName      = try c.decodeIfPresent(String.self, forKey: .accountName)
        categoryId       = try c.decodeIfPresent(String.self, forKey: .categoryId)
        categoryName     = try c.decodeIfPresent(String.self, forKey: .categoryName)
        categoryGroupName = try c.decodeIfPresent(String.self, forKey: .categoryGroupName)
        payeeId          = try c.decodeIfPresent(String.self, forKey: .payeeId)
        payeeName        = try c.decodeIfPresent(String.self, forKey: .payeeName)
        date             = try c.decode(String.self, forKey: .date)
        memo             = try c.decodeIfPresent(String.self, forKey: .memo)
        cleared          = try c.decode(Bool.self, forKey: .cleared)
        createdAt        = try c.decodeIfPresent(String.self, forKey: .createdAt)
        // Accept Int or String (Neon serialises BIGINT as a JSON string)
        if let intVal = try? c.decode(Int.self, forKey: .amount) {
            amount = intVal
        } else {
            let strVal = try c.decode(String.self, forKey: .amount)
            guard let parsed = Int(strVal) else {
                throw DecodingError.dataCorruptedError(forKey: .amount, in: c,
                    debugDescription: "Cannot convert \"\(strVal)\" to Int")
            }
            amount = parsed
        }
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
